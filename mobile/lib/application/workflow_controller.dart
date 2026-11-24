import 'dart:async';

import 'package:excelcompare_core/excelcompare_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Locale;

import '../domain/smart_proposal_engine.dart';
import '../domain/workflow.dart';
import '../domain/workbook_comparison.dart';
import '../infrastructure/database/comparison_database.dart';
import '../infrastructure/file_upload_service.dart';
import '../ocr/infrastructure/ocr_capture_service.dart';
import '../l10n/app_localizations.dart';

export '../infrastructure/database/comparison_database.dart' show SavedSessionSummary;

final class _Work {
  final cancel = Cancellation();
  final stopped = Completer<void>();
  Future<void> stop() {
    cancel.cancel();
    return stopped.future;
  }
}

/// Activity coordinator. Views send commands; all readiness/invalidation guards
/// live here. Ports must settle only after their owned resources are closed.
final class WorkflowController extends ChangeNotifier {
  WorkflowController({
    required this.input,
    required this.comparator,
    required this.exporter,
    this.maxAttempts = 3,
  }) {
    if (maxAttempts < 1) throw ArgumentError.value(maxAttempts, 'maxAttempts');
  }
  final InputPort input;
  final ComparisonPort comparator;
  final ExportPort exporter;
  final int maxAttempts;
  final _slots = {
    for (final side in SourceSide.values) side: SourceSlot(side: side),
  };
  final Map<SourceSide, _Work> _imports = {};
  _Work? _comparison;
  _Work? _export;
  bool _disposed = false;
  bool _closing = false;
  int _serial = 0;
  int _planRevision = 0;
  int _jobAttempts = 0;
  int _exportAttempts = 0;
  WorkflowScreen screen = WorkflowScreen.home;
  SourceSide activeSide = SourceSide.a;
  ComparisonTaskMode taskMode = ComparisonTaskMode.compareFiles;
  SmartProposal? proposal;
  ComparisonConfiguration config = ComparisonConfiguration();
  JobState jobState = JobState.created;
  ExportState? exportState;
  ComparisonResult? result;
  ResultValidity validity = ResultValidity.stale;
  ExportReceipt? receipt;
  WorkflowIssue? issue;
  String phase = '';
  Locale _locale = const Locale('en');
  Locale get locale => _locale;
  void setLocale(Locale loc) {
    if (_locale == loc) return;
    _locale = loc;
    AppLocalizations.current = AppLocalizations(loc);
    _emit();
  }
  void toggleLocale() {
    setLocale(_locale.languageCode == 'vi' ? const Locale('en') : const Locale('vi'));
  }
  AppLocalizations get l10n => AppLocalizations(_locale);
  int progressDone = 0;
  int? progressTotal;
  DecisionStatus? resultFilter;
  int page = 0;
  String? detailId;
  String? selectedSheetPairId;
  final List<(String?, String?)> sheetOverrides = [];
  SheetMappingPlan? _cachedSheetMapping;
  bool get hasWorkbook => SourceSide.values.any(
    (s) => slot(s).snapshot?.workbookSheets.isNotEmpty == true,
  );
  SourceSide? _duplicateSlotSide;
  SourceSide? get duplicateSlotSide =>
      duplicateSourceFiles ? (_duplicateSlotSide ?? SourceSide.b) : null;

  String? _digestOf(SourceSlot s) {
    final ref = s.artifact?.privateRef;
    if (ref == null) return null;
    return MobileFileUploadService.sha256Of(ref) ??
        OcrCaptureService.sha256Of(ref);
  }

  bool get duplicateSourceFiles {
    final a = slot(SourceSide.a);
    final b = slot(SourceSide.b);
    if (a.artifact == null || b.artifact == null) return false;
    final hashA = _digestOf(a);
    final hashB = _digestOf(b);
    if (hashA != null && hashB != null) {
      return hashA == hashB;
    }
    return false;
  }

  SheetMappingPlan? get sheetMapping => !inputsReady || !hasWorkbook
      ? null
      : (_cachedSheetMapping ??= mapWorkbookSnapshots(
          slot(SourceSide.a).snapshot!,
          slot(SourceSide.b).snapshot!,
          overrides: sheetOverrides,
        ));
  bool get structuralWorkbookOnly {
    final mapping = sheetMapping;
    if (mapping == null || !mapping.complete) return false;
    final a = workbookTables(slot(SourceSide.a).snapshot!),
        b = workbookTables(slot(SourceSide.b).snapshot!);
    return mapping.pairs.every(
      (p) =>
          p.a == null ||
          p.b == null ||
          !a[p.a!].fields.any(
            (fa) => b[p.b!].fields.any(
              (fb) =>
                  normalizeSheetLabel(fa.label) ==
                  normalizeSheetLabel(fb.label),
            ),
          ),
    );
  }

  ComparisonResult? get displayedResult =>
      result?.sheetResults
          .where((r) => r.sheetPair?.id == selectedSheetPairId)
          .firstOrNull ??
      result;
  void selectResultSheet(String? id) {
    selectedSheetPairId = id;
    page = 0;
    _emit();
  }

  void resolveSheetPair(String? a, String? b) {
    if (!inputsReady || busy) return;
    mapWorkbookSnapshots(
      slot(SourceSide.a).snapshot!,
      slot(SourceSide.b).snapshot!,
      overrides: [...sheetOverrides, (a, b)],
    );
    sheetOverrides.add((a, b));
    _cachedSheetMapping = null;
    _invalidate();
    _alignWorkbookPreviews();
    analyzeAndPropose();
  }

  static const pageSize = 12;
  String _id(String prefix) => '$prefix-${++_serial}';
  SourceSlot slot(SourceSide side) => _slots[side]!;
  bool get inputsReady => SourceSide.values.every((s) => slot(s).ready);
  bool get busy =>
      _imports.isNotEmpty || _comparison != null || _export != null || _closing;
  bool get resultCurrent =>
      result != null &&
      validity == ResultValidity.current &&
      jobState == JobState.completed;
  bool get usable => !_disposed && !_closing;

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  WorkflowIssue _safe(Object error) => error is WorkflowIssue
      ? error
      : WorkflowIssue(
          'ACTIVITY_FAILED',
          l10n.activityFailed,
        );
  void _invalidate({bool source = false, bool revoked = false}) {
    _planRevision++;
    _jobAttempts = 0;
    _exportAttempts = 0;
    validity = revoked ? ResultValidity.revoked : ResultValidity.stale;
    receipt = null;
    _cachedSheetMapping = null;
    _comparison?.cancel.cancel();
    _export?.cancel.cancel();
    if (_comparison != null) jobState = JobState.cancelling;
    if (_export != null) exportState = ExportState.cancelling;
    if (source) {
      sheetOverrides.clear();
      selectedSheetPairId = null;
      config = ComparisonConfiguration();
      proposal = null;
    }
  }

  Future<void> selectSource(
    SourceSide side,
    SourceFormat format,
    String privateRef,
    String label,
  ) async {
    if (!usable) return;
    final other = slot(side == SourceSide.a ? SourceSide.b : SourceSide.a);
    final isFixtureImagePair =
        privateRef.startsWith('fixture:') &&
        (other.artifact?.privateRef.startsWith('fixture:') ?? false) &&
        format.isImage &&
        other.artifact?.format.isImage == true;
    if (isFixtureImagePair) {
      issue = WorkflowIssue(
        'IMAGE_PAIR_UNSUPPORTED',
        l10n.imagePairUnsupported,
      );
      _emit();
      return;
    }
    final oldRef = slot(side).artifact?.privateRef;
    final old = _imports[side];
    old?.cancel.cancel();
    final next = SourceSlot(
      side: side,
      state: InputState.selected,
      artifact: SourceArtifact(
        id: _id('artifact'),
        label: label,
        format: format,
        privateRef: privateRef,
      ),
      generation: slot(side).generation + 1,
    );
    final otherHash = _digestOf(other);
    final nextHash =
        MobileFileUploadService.sha256Of(privateRef) ??
        OcrCaptureService.sha256Of(privateRef);
    _slots[side] = next;
    _invalidate(source: true);
    _duplicateSlotSide =
        (otherHash != null && nextHash != null && otherHash == nextHash)
            ? side
            : null;
    issue = null;
    _emit();
    // Replacement is selectable immediately; new work waits for old cleanup.
    if (old != null) await old.stopped.future;
    if (oldRef != null &&
        !_slots.values.any((s) => s.artifact?.privateRef == oldRef) &&
        input is InputCleanupPort) {
      (input as InputCleanupPort).release(oldRef);
    }
  }

  Future<void> resetSource(SourceSide side) async {
    if (!usable) return;
    final oldRef = slot(side).artifact?.privateRef;
    final old = _imports[side];
    old?.cancel.cancel();
    _slots[side] = SourceSlot(
      side: side,
      generation: slot(side).generation + 1,
    );
    _duplicateSlotSide = null;
    _invalidate(source: true);
    _emit();
    if (old != null) await old.stopped.future;
    if (oldRef != null &&
        !_slots.values.any((s) => s.artifact?.privateRef == oldRef) &&
        input is InputCleanupPort) {
      (input as InputCleanupPort).release(oldRef);
    }
  }

  Future<void> changeImportConfig(
    SourceSide side,
    ImportConfiguration value,
  ) async {
    if (!usable || slot(side).artifact == null) return;
    final oldWork = _imports[side];
    oldWork?.cancel.cancel();
    final old = slot(side);
    final frozen = ImportConfiguration(
      scopeConfirmed: value.scopeConfirmed,
      ocrRevision: value.ocrRevision,
      reviewedCells: Set.unmodifiable(value.reviewedCells),
    );
    _slots[side] = SourceSlot(
      side: side,
      state: InputState.selected,
      artifact: old.artifact,
      generation: old.generation,
      revision: old.revision + 1,
      config: frozen,
    );
    _invalidate(source: true);
    _emit();
    if (oldWork != null) await oldWork.stopped.future;
  }

  Future<void> importSource(SourceSide side) async {
    if (!usable || _imports.containsKey(side)) return;
    final old = slot(side);
    if (!const {
          InputState.selected,
          InputState.failed,
          InputState.cancelled,
        }.contains(old.state) ||
        old.artifact == null) {
      return;
    }
    if (old.state == InputState.failed && old.issue?.retryable != true) return;
    if (old.attempt >= maxAttempts) {
      issue = WorkflowIssue(
        'RETRY_LIMIT',
        l10n.retryLimitExceeded,
      );
      _emit();
      return;
    }
    final work = _Work();
    _imports[side] = work;
    final binding = ImportBinding(
      old.artifact!.id,
      old.generation,
      old.revision,
      old.attempt + 1,
    );
    void set(
      InputState state, {
      InputSnapshot? snapshot,
      ImportReview? review,
      WorkflowIssue? issue,
    }) {
      _slots[side] = SourceSlot(
        side: side,
        state: state,
        artifact: old.artifact,
        generation: binding.generation,
        revision: binding.revision,
        attempt: binding.attempt,
        config: old.config,
        snapshot: snapshot,
        review: review,
        issue: issue,
      );
    }

    set(InputState.preflighting);
    bool current() =>
        usable && !work.cancel.cancelled && slot(side).binding == binding;
    _emit();
    try {
      final outcome = await input.importSource(
        old.artifact!,
        binding,
        old.config,
        work.cancel,
        () {
          if (current() && slot(side).state == InputState.preflighting) {
            set(InputState.parsing);
            _emit();
          }
        },
      );
      if (!current()) return;
      if (outcome.review != null) {
        set(
          InputState.needsReview,
          review: outcome.review,
          issue: outcome.review!.issue,
        );
      } else {
        final snapshot = outcome.snapshot;
        if (slot(side).state != InputState.parsing ||
            snapshot == null ||
            snapshot.binding != binding ||
            !snapshot.fullValidation ||
            (old.artifact!.format.isImage && !snapshot.ocrReviewed)) {
          throw WorkflowIssue(
            'SNAPSHOT_NOT_VALIDATED',
            l10n.snapshotNotValidated,
          );
        }
        set(InputState.previewReady, snapshot: snapshot);
      }
    } on WorkCancelled {
      // The cancelling command commits CANCELLED after this finally boundary.
    } catch (error) {
      if (current()) set(InputState.failed, issue: _safe(error));
    } finally {
      if (identical(_imports[side], work)) _imports.remove(side);
      work.stopped.complete();
      if (inputsReady) {
        _alignWorkbookPreviews();
        analyzeAndPropose();
      } else {
        _emit();
      }
    }
  }

  void selectWorkbookPreview(SourceSide side, String name) {
    if (!inputsReady || busy || !hasWorkbook) return;
    _invalidate();
    config = ComparisonConfiguration();
    _alignWorkbookPreviews(preferredSide: side, preferredName: name);
    analyzeAndPropose();
  }

  void _alignWorkbookPreviews({
    SourceSide? preferredSide,
    String? preferredName,
  }) {
    final mapping = sheetMapping;
    if (mapping == null) return;
    final candidates = mapping.pairs
        .where((p) => p.a != null && p.b != null)
        .toList();
    final ta = workbookTables(slot(SourceSide.a).snapshot!),
        tb = workbookTables(slot(SourceSide.b).snapshot!);
    int value(SheetPair p) {
      final a = ta[p.a!], b = tb[p.b!];
      final bLabels =
          b.fields.map((fb) => normalizeSheetLabel(fb.label)).toSet();
      final shared = a.fields
          .where((fa) => bLabels.contains(normalizeSheetLabel(fa.label)))
          .length;
      return shared * 2 +
          (a.records.isNotEmpty && b.records.isNotEmpty ? 1 : 0);
    }

    final scores = {for (final p in candidates) p.id: value(p)};
    candidates.sort((a, b) => scores[b.id]!.compareTo(scores[a.id]!));
    final pair = preferredName == null
        ? candidates.firstOrNull
        : candidates
              .where(
                (p) =>
                    (preferredSide == SourceSide.a ? p.nameA : p.nameB) ==
                    preferredName,
              )
              .firstOrNull;
    if (pair == null && preferredName != null && preferredSide != null) {
      final old = slot(preferredSide), original = old.snapshot!;
      final selected = workbookTables(original)
          .where((s) => s.sheetName == preferredName)
          .firstOrNull;
      if (selected != null) {
        _slots[preferredSide] = SourceSlot(
          side: preferredSide,
          state: old.state,
          artifact: old.artifact,
          generation: old.generation,
          revision: old.revision,
          attempt: old.attempt,
          config: old.config,
          snapshot: InputSnapshot(
            id: selected.id,
            binding: original.binding,
            fields: selected.fields,
            records: selected.records,
            fullValidation: original.fullValidation,
            ocrReviewed: original.ocrReviewed,
            sheetName: selected.sheetName,
            workbookSheets: original.workbookSheets,
            warnings: original.warnings,
          ),
        );
      }
      return;
    }
    if (pair == null) return;
    for (final side in SourceSide.values) {
      final slotNow = slot(side),
          original = slotNow.snapshot!,
          tables = workbookTables(original);
      final selected = tables[side == SourceSide.a ? pair.a! : pair.b!];
      _slots[side] = SourceSlot(
        side: side,
        state: slotNow.state,
        artifact: slotNow.artifact,
        generation: slotNow.generation,
        revision: slotNow.revision,
        attempt: slotNow.attempt,
        config: slotNow.config,
        snapshot: InputSnapshot(
          id: selected.id,
          binding: original.binding,
          fields: selected.fields,
          records: selected.records,
          fullValidation: original.fullValidation,
          ocrReviewed: original.ocrReviewed,
          sheetName: selected.sheetName,
          workbookSheets: original.workbookSheets,
          warnings: original.warnings,
        ),
      );
    }
  }

  Future<void> confirmImport(
    SourceSide side, {
    required ImportBinding expectedBinding,
    Set<String> reviewedCells = const {},
  }) async {
    final old = slot(side);
    if (!usable ||
        old.state != InputState.needsReview ||
        old.binding != expectedBinding) {
      return;
    }
    if (old.review!.cells.any((c) => !reviewedCells.contains(c.id))) {
      issue = WorkflowIssue(
        'OCR_REVIEW_REQUIRED',
        l10n.ocrReviewRequired,
      );
      _emit();
      return;
    }
    await changeImportConfig(
      side,
      ImportConfiguration(
        scopeConfirmed: true,
        ocrRevision: old.config.ocrRevision,
        reviewedCells: reviewedCells,
      ),
    );
    // A concurrent replace/reset must never import the newly selected artifact
    // using this old review action.
    if (slot(side).artifact?.id == old.artifact?.id &&
        slot(side).revision == old.revision + 1) {
      issue = null;
      await importSource(side);
    }
  }

  Future<void> cancelImport(SourceSide side) async {
    if (!usable) return;
    final old = slot(side);
    if (old.artifact == null ||
        old.state == InputState.cancelled ||
        old.state == InputState.failed) {
      return;
    }
    final work = _imports[side];
    work?.cancel.cancel();
    _slots[side] = SourceSlot(
      side: side,
      state: old.state,
      artifact: old.artifact,
      generation: old.generation,
      revision: old.revision,
      attempt: old.attempt,
      config: old.config,
      cancelling: true,
    );
    _invalidate(source: true);
    _emit();
    if (work != null) await work.stopped.future;
    if (!usable || slot(side).binding != old.binding) return;
    _slots[side] = SourceSlot(
      side: side,
      state: InputState.cancelled,
      artifact: old.artifact,
      generation: old.generation,
      revision: old.revision,
      attempt: old.attempt,
      config: old.config,
    );
    _emit();
  }

  Future<void> revokeSource(SourceSide side) async {
    if (!usable || slot(side).artifact == null) return;
    final old = slot(side);
    final work = _imports[side];
    work?.cancel.cancel();
    _slots[side] = SourceSlot(
      side: side,
      state: InputState.failed,
      artifact: old.artifact,
      generation: old.generation + 1,
      issue: WorkflowIssue(
        'INP-ERR-006',
        l10n.accessRevoked,
      ),
    );
    _invalidate(source: true, revoked: true);
    _emit();
    if (work != null) await work.stopped.future;
  }

  void configure(ComparisonConfiguration next) {
    if (!usable) return;
    config = next;
    _invalidate();
    issue = null;
    _emit();
  }

  void setTaskMode(ComparisonTaskMode mode) {
    if (!usable) return;
    taskMode = mode;
    if (inputsReady) {
      analyzeAndPropose();
    } else {
      _emit();
    }
  }

  void analyzeAndPropose({
    String? preferredKey,
    String? columnA,
    String? columnB,
    String? reconcileValueColumn,
  }) {
    if (!usable || !inputsReady) return;
    final a = slot(SourceSide.a).snapshot!;
    final b = slot(SourceSide.b).snapshot!;
    proposal = SmartProposalEngine.analyze(
      a,
      b,
      taskMode: taskMode,
      preferredKey: preferredKey,
      columnA: columnA,
      columnB: columnB,
      reconcileValueColumn: reconcileValueColumn,
    );
    _emit();
  }

  void applyProposal({bool run = false}) {
    if (!usable || !inputsReady) return;
    if (proposal == null) {
      analyzeAndPropose();
    }
    if (proposal != null) {
      config = SmartProposalEngine.toConfiguration(
        proposal!,
        direction: config.direction,
      );
      if (structuralWorkbookOnly) {
        config = config.copyWith(mappingConfirmed: true);
      }
      _invalidate();
      issue = null;
      _emit();
      if (run && startBlockers.isEmpty && !busy) {
        runComparison();
      }
    }
  }

  List<WorkflowIssue> get startBlockers {
    final blockers = <WorkflowIssue>[];
    if (sheetMapping?.complete == false) {
      blockers.add(
        WorkflowIssue(
          'SHEET_MAPPING_REQUIRED',
          l10n.sheetMappingRequired,
        ),
      );
    }
    for (final side in SourceSide.values) {
      if (!slot(side).ready) {
        blockers.add(
          WorkflowIssue(
            'INPUT_NOT_READY',
            l10n.inputNotReady(side.name.toUpperCase()),
          ),
        );
      }
    }
    if (!config.mappingConfirmed ||
        (config.mappings.isEmpty && !structuralWorkbookOnly)) {
      blockers.add(
        WorkflowIssue(
          'MAPPING_CONFIRMATION_REQUIRED',
          l10n.mappingConfirmationRequired,
        ),
      );
    }
    if (!config.modeConfirmed) {
      blockers.add(
        WorkflowIssue(
          'MODE_CONFIRMATION_REQUIRED',
          l10n.modeConfirmationRequired,
        ),
      );
    }
    if (!config.policyConfirmed) {
      blockers.add(
        WorkflowIssue(
          'POLICY_CONFIRMATION_REQUIRED',
          l10n.policyConfirmationRequired,
        ),
      );
    }
    if (!config.directionConfirmed) {
      blockers.add(
        WorkflowIssue(
          'DIRECTION_CONFIRMATION_REQUIRED',
          l10n.directionConfirmationRequired,
        ),
      );
    }
    if (config.mode == MatchingMode.key &&
        (config.keys.isEmpty ||
            config.keys.toSet().length != config.keys.length ||
            config.keys.any(
              (k) =>
                  !config.mappings.any((m) => m.fieldA == k) ||
                  config.rules[k]?.type != SemanticType.identifier ||
                  config.rules[k]?.tolerance != '0' ||
                  config.rules[k]?.trim != false,
            ))) {
      blockers.add(
        WorkflowIssue(
          'KEY_INVALID',
          l10n.keyInvalid,
        ),
      );
    }
    if (inputsReady) {
      final a = slot(SourceSide.a).snapshot!.fields.map((f) => f.id).toSet();
      final b = slot(SourceSide.b).snapshot!.fields.map((f) => f.id).toSet();
      if (config.mappings.map((m) => m.fieldA).toSet().length !=
              config.mappings.length ||
          config.mappings.map((m) => m.fieldB).toSet().length !=
              config.mappings.length ||
          config.mappings.any(
            (m) => !a.contains(m.fieldA) || !b.contains(m.fieldB),
          )) {
        blockers.add(
          WorkflowIssue(
            'MAPPING_INVALID',
            l10n.mappingInvalid,
          ),
        );
      }
    }
    for (final mapping in config.mappings) {
      try {
        final rule = config.rules[mapping.fieldA];
        if (rule == null) throw const FormatException();
        rule.compile(mapping.fieldA);
      } on FormatException {
        blockers.add(
          WorkflowIssue(
            'POLICY_INVALID',
            l10n.policyInvalid,
          ),
        );
      }
    }
    blockers.addAll(comparator.startBlockers);
    return List.unmodifiable(blockers);
  }

  Future<void> runComparison() async {
    if (!usable || _comparison != null || _export != null) return;
    if (startBlockers.isNotEmpty) {
      issue = startBlockers.first;
      _emit();
      return;
    }
    if (_jobAttempts >= maxAttempts) {
      issue = WorkflowIssue(
        'RETRY_LIMIT',
        l10n.retryLimitConfig,
      );
      _emit();
      return;
    }
    _jobAttempts++;
    final plan = FrozenPlan(
      _id('plan'),
      _planRevision,
      slot(SourceSide.a).snapshot!,
      slot(SourceSide.b).snapshot!,
      config,
      sheetOverrides: List.unmodifiable(sheetOverrides),
    );
    final work = _Work();
    _comparison = work;
    validity = ResultValidity.stale;
    receipt = null;
    issue = null;
    phase = l10n.validatingConfigPhase;
    progressDone = 0;
    progressTotal = null;
    jobState = JobState.validating;
    screen = WorkflowScreen.progress;
    _emit();
    bool current() =>
        usable && !work.cancel.cancelled && plan.revision == _planRevision;
    try {
      await Future<void>.delayed(Duration.zero);
      work.cancel.check();
      if (!current()) return;
      jobState = JobState.running;
      _emit();
      final output = await comparator.compare(plan, work.cancel, (
        p,
        done,
        total,
      ) {
        if (!current() || jobState != JobState.running) return;
        if (done < 0 ||
            (total != null && (total < done || total < 0)) ||
            (p == phase && done < progressDone)) {
          throw WorkflowIssue(
            'PROGRESS_INVALID',
            l10n.progressInvalid,
          );
        }
        phase = p;
        progressDone = done;
        progressTotal = total;
        _emit();
      });
      if (!current()) return;
      if (!identical(output.plan, plan) || output.id.isEmpty) {
        throw WorkflowIssue(
          'RESULT_BINDING_INVALID',
          l10n.resultBindingInvalid,
        );
      }
      result = output;
      selectedSheetPairId = null;
      validity = ResultValidity.current;
      jobState = JobState.completed;
      resultFilter = null;
      page = 0;
      detailId = null;
      screen = WorkflowScreen.results;
      // Persist in SQLite asynchronously for multi-app resilience & crash recovery
      unawaited(
        ComparisonDatabase.instance.saveSession(
          result: output,
          labelA: slot(SourceSide.a).artifact?.label ?? l10n.sourceA,
          labelB: slot(SourceSide.b).artifact?.label ?? l10n.sourceB,
          formatA: slot(SourceSide.a).artifact?.format ?? SourceFormat.csv,
          formatB: slot(SourceSide.b).artifact?.format ?? SourceFormat.csv,
          config: config,
        ).then((_) async {
          _lastSavedSession = await ComparisonDatabase.instance.getActiveSessionSummary();
          _emit();
        }).catchError((_) {}),
      );
    } on WorkCancelled {
      jobState = JobState.cancelled;
    } catch (error) {
      if (current()) {
        issue = _safe(error);
        jobState = JobState.failed;
      }
    } finally {
      if (jobState == JobState.cancelling) jobState = JobState.cancelled;
      if (identical(_comparison, work)) _comparison = null;
      work.stopped.complete();
      _emit();
    }
  }

  Future<void> cancelComparison() async {
    final work = _comparison;
    if (work == null) return; // A late cancel never changes a terminal result.
    jobState = JobState.cancelling;
    _emit();
    await work.stop();
  }

  bool navigate(WorkflowScreen target, {SourceSide? side, String? cellId}) {
    if (!usable || _comparison != null || _export != null) return false;
    if (const {
          WorkflowScreen.mapping,
          WorkflowScreen.policy,
        }.contains(target) &&
        !inputsReady) {
      return false;
    }
    if (const {
          WorkflowScreen.results,
          WorkflowScreen.detail,
          WorkflowScreen.export,
        }.contains(target) &&
        !resultCurrent) {
      return false;
    }
    if (target == WorkflowScreen.ocrReview &&
        slot(side ?? activeSide).review?.cells.isNotEmpty != true) {
      return false;
    }
    if (target == WorkflowScreen.detail &&
        !result!.cells.any((c) => c.id == cellId)) {
      return false;
    }
    if (target == WorkflowScreen.progress &&
        !jobState.active &&
        jobState != JobState.cancelled &&
        jobState != JobState.failed) {
      return false;
    }
    activeSide = side ?? activeSide;
    detailId = cellId ?? detailId;
    screen = target;
    _emit();
    return true;
  }

  void filterResults(DecisionStatus? filter) {
    if (!resultCurrent) return;
    resultFilter = filter;
    page = 0;
    _emit();
  }

  List<CellDifference> get selectedCells => !resultCurrent
      ? const []
      : displayedResult!.cells
            .where(
              (c) => resultFilter == null || c.decision.status == resultFilter,
            )
            .toList(growable: false);
  List<CellDifference> get visibleCells => selectedCells
      .skip(page * pageSize)
      .take(pageSize)
      .toList(growable: false);
  void turnPage(int delta) {
    final next = page + delta;
    if (resultCurrent &&
        next >= 0 &&
        (next == 0 || next * pageSize < selectedCells.length)) {
      page = next;
      _emit();
    }
  }

  Future<void> exportResult(ExportRequest request) async {
    if (!usable || _export != null || _comparison != null) return;
    if (!resultCurrent) {
      issue = WorkflowIssue(
        'RESULT_NOT_CURRENT',
        l10n.resultNotCurrent,
      );
      _emit();
      return;
    }
    if (!exporter.supports(request.kind)) {
      issue = WorkflowIssue(
        'EXPORT_CAPABILITY_DISABLED',
        l10n.exportDisabled,
      );
      _emit();
      return;
    }
    if (_exportAttempts >= maxAttempts) {
      issue = WorkflowIssue(
        'RETRY_LIMIT',
        l10n.exportRetriesExceeded,
      );
      _emit();
      return;
    }
    _exportAttempts++;
    final work = _Work();
    _export = work;
    final output = result!;
    final attempt = _id('export');
    PreparedExport? pending;
    exportState = ExportState.requested;
    receipt = null;
    issue = null;
    _emit();
    void check() {
      work.cancel.check();
      if (!resultCurrent || !identical(result, output)) {
        throw WorkflowIssue(
          'RESULT_NOT_CURRENT',
          l10n.resultStale,
        );
      }
    }

    try {
      exportState = ExportState.validating;
      _emit();
      check();
      exportState = ExportState.rendering;
      _emit();
      pending = await exporter.render(output, request, work.cancel);
      check();
      exportState = ExportState.verifying;
      _emit();
      await exporter.verify(pending, work.cancel);
      check();
      exportState = ExportState.publishing;
      _emit();
      final published = await exporter.publish(pending, attempt, work.cancel);
      // Publish owns the durable boundary. A late cancel cannot undo it.
      receipt = published;
      exportState = ExportState.completed;
    } on WorkCancelled {
      exportState = ExportState.cancelling;
      _emit();
    } catch (error) {
      issue = _safe(error);
      exportState = ExportState.failed;
    } finally {
      try {
        await exporter.discard(pending);
        if (exportState == ExportState.cancelling) {
          exportState = ExportState.cancelled;
        }
      } catch (_) {
        issue = WorkflowIssue(
          'CLEANUP_FAILED',
          l10n.cleanupFailed,
        );
        if (exportState != ExportState.completed) {
          exportState = ExportState.failed;
        }
      }
      if (identical(_export, work)) _export = null;
      work.stopped.complete();
      _emit();
    }
  }

  Future<void> cancelExport() async {
    final work = _export;
    if (work == null || exportState == ExportState.completed) return;
    exportState = ExportState.cancelling;
    _emit();
    await work.stop();
  }

  SavedSessionSummary? _lastSavedSession;
  SavedSessionSummary? get lastSavedSession => _lastSavedSession;

  /// Loads the most recent persisted session summary from SQLite.
  Future<void> loadLastSavedSession() async {
    _lastSavedSession = await ComparisonDatabase.instance.getActiveSessionSummary();
    _emit();
  }

  /// Returns total count of persisted sessions in SQLite.
  Future<int> countSavedSessions() =>
      ComparisonDatabase.instance.countSessions();

  /// Returns total local storage usage in bytes (persisted SQLite sessions + active in-memory session).
  Future<int> getLocalStorageUsageBytes() async {
    int total = await ComparisonDatabase.instance.getStorageUsageBytes();
    total += MobileFileUploadService.estimatedMemoryBytes();
    total += OcrCaptureService.estimatedMemoryBytes();
    for (final side in SourceSide.values) {
      final snap = slot(side).snapshot;
      if (snap != null) {
        total += snap.records.length * snap.fields.length * 32;
      }
    }
    return total;
  }

  /// Formats byte count into a clean human-readable string (e.g. "0 KB", "24.5 KB", "1.2 MB").
  static String formatStorageBytes(int bytes) {
    if (bytes <= 0) return '0 KB';
    if (bytes < 1024) return '< 1 KB';
    final kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb >= 100 ? kb.toStringAsFixed(0) : kb.toStringAsFixed(1)} KB';
    }
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  /// Queries persisted sessions from SQLite for the Home and History screens.
  Future<List<SavedSessionSummary>> getRecentSavedSessions({
    int limit = 10,
    int offset = 0,
  }) =>
      ComparisonDatabase.instance.listRecentSessions(
        limit: limit,
        offset: offset,
      );

  /// Deletes a specific saved comparison session from SQLite.
  Future<void> deleteSavedSession(String sessionId) async {
    await ComparisonDatabase.instance.deleteSession(sessionId);
    await loadLastSavedSession();
    _emit();
  }

  /// Wipes all saved comparison sessions from SQLite.
  Future<void> clearAllSavedSessions() async {
    await ComparisonDatabase.instance.clearAll();
    _lastSavedSession = null;
    _emit();
  }

  /// Restores a previously completed comparison session from SQLite.
  /// Survives app process death when multiple apps are running on the device.
  Future<bool> restoreSavedSession(String sessionId) async {
    if (!usable || busy) return false;
    final restored = await ComparisonDatabase.instance.loadSession(sessionId);
    if (restored == null) return false;
    result = restored;
    validity = ResultValidity.current;
    jobState = JobState.completed;
    resultFilter = null;
    page = 0;
    detailId = null;
    screen = WorkflowScreen.results;
    _emit();
    return true;
  }

  /// Session close is awaited by the UI. No automatic background resume.
  Future<void> closeSession() async {
    if (_closing || _disposed) return;
    _closing = true;
    final works = [..._imports.values, ?_comparison, ?_export];
    for (final work in works) {
      work.cancel.cancel();
    }
    _emit();
    await Future.wait(works.map((w) => w.stopped.future));
    if (input case final InputCleanupPort cleanup) {
      for (final source in _slots.values) {
        if (source.artifact != null) {
          cleanup.release(source.artifact!.privateRef);
        }
      }
    }
    for (final side in SourceSide.values) {
      _slots[side] = SourceSlot(
        side: side,
        generation: slot(side).generation + 1,
      );
    }
    config = ComparisonConfiguration();
    taskMode = ComparisonTaskMode.compareFiles;
    proposal = null;
    result = null;
    receipt = null;
    issue = null;
    validity = ResultValidity.stale;
    jobState = JobState.created;
    exportState = null;
    resultFilter = null;
    detailId = null;
    page = 0;
    _planRevision++;
    _jobAttempts = 0;
    _exportAttempts = 0;
    screen = WorkflowScreen.home;
    _closing = false;
    _emit();
  }

  /// Startup entry point for a future private journal adapter. Never restores
  /// READY/results or raw data. Available refs must go through import again.
  Future<void> restoreSources(
    Map<SourceSide, SourceArtifact> availableRefs, {
    bool interruptedJob = false,
  }) async {
    await closeSession();
    if (!usable) return;
    for (final entry in availableRefs.entries) {
      final artifact = entry.value;
      _slots[entry.key] = SourceSlot(
        side: entry.key,
        state: InputState.selected,
        generation: slot(entry.key).generation + 1,
        artifact: artifact,
        issue: WorkflowIssue(
          'INP-ERR-018',
          l10n.sourceRevalidationRequired,
        ),
      );
    }
    jobState = interruptedJob ? JobState.interrupted : JobState.created;
    screen = WorkflowScreen.sources;
    _emit();
  }

  @override
  void dispose() {
    _disposed = true;
    if (input case final InputCleanupPort cleanup) {
      for (final source in _slots.values) {
        if (source.artifact != null) {
          cleanup.release(source.artifact!.privateRef);
        }
      }
    }
    for (final work in [..._imports.values, ?_comparison, ?_export]) {
      work.cancel.cancel();
    }
    super.dispose();
  }
}
