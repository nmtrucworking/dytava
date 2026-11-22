import 'dart:async';

import 'package:excelcompare_core/excelcompare_core.dart';
import 'package:flutter/foundation.dart';

import '../domain/smart_proposal_engine.dart';
import '../domain/workflow.dart';
import '../domain/workbook_comparison.dart';

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
  int progressDone = 0;
  int? progressTotal;
  DecisionStatus? resultFilter;
  int page = 0;
  String? detailId;
  String? selectedSheetPairId;
  final List<(String?, String?)> sheetOverrides = [];
  bool get hasWorkbook => SourceSide.values.any(
    (s) => slot(s).snapshot?.workbookSheets.isNotEmpty == true,
  );
  SheetMappingPlan? get sheetMapping => !inputsReady || !hasWorkbook
      ? null
      : mapWorkbookSnapshots(
          slot(SourceSide.a).snapshot!,
          slot(SourceSide.b).snapshot!,
          overrides: sheetOverrides,
        );
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
      : const WorkflowIssue(
          'ACTIVITY_FAILED',
          'Tác vụ thất bại. Hãy kiểm tra lại nguồn và cấu hình.',
        );
  void _invalidate({bool source = false, bool revoked = false}) {
    _planRevision++;
    _jobAttempts = 0;
    _exportAttempts = 0;
    validity = revoked ? ResultValidity.revoked : ResultValidity.stale;
    receipt = null;
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
    if (format.isImage && other.artifact?.format.isImage == true) {
      issue = const WorkflowIssue(
        'IMAGE_PAIR_UNSUPPORTED',
        'P0 chỉ cho phép một nguồn ảnh; phía còn lại phải là bảng.',
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
    _slots[side] = next;
    _invalidate(source: true);
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
      issue = const WorkflowIssue(
        'RETRY_LIMIT',
        'Đã hết số lần thử. Hãy chọn lại nguồn.',
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
          throw const WorkflowIssue(
            'SNAPSHOT_NOT_VALIDATED',
            'Nguồn chưa có bằng chứng xác thực đầy đủ.',
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
      final shared = a.fields
          .where(
            (fa) => b.fields.any(
              (fb) =>
                  normalizeSheetLabel(fa.label) ==
                  normalizeSheetLabel(fb.label),
            ),
          )
          .length;
      return shared * 2 +
          (a.records.isNotEmpty && b.records.isNotEmpty ? 1 : 0);
    }

    candidates.sort((a, b) => value(b).compareTo(value(a)));
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
      issue = const WorkflowIssue(
        'OCR_REVIEW_REQUIRED',
        'Cần xác nhận mọi ô trong phạm vi ảnh.',
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
      issue: const WorkflowIssue(
        'INP-ERR-006',
        'Quyền truy cập nguồn đã bị thu hồi.',
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
        const WorkflowIssue(
          'SHEET_MAPPING_REQUIRED',
          'Cần chọn các cặp sheet chưa xác định được.',
        ),
      );
    }
    for (final side in SourceSide.values) {
      if (!slot(side).ready) {
        blockers.add(
          WorkflowIssue(
            'INPUT_NOT_READY',
            'Nguồn ${side.name.toUpperCase()} chưa PREVIEW_READY.',
          ),
        );
      }
    }
    if (!config.mappingConfirmed ||
        (config.mappings.isEmpty && !structuralWorkbookOnly)) {
      blockers.add(
        const WorkflowIssue(
          'MAPPING_CONFIRMATION_REQUIRED',
          'Cần xác nhận ánh xạ ít nhất một cặp cột.',
        ),
      );
    }
    if (!config.modeConfirmed) {
      blockers.add(
        const WorkflowIssue(
          'MODE_CONFIRMATION_REQUIRED',
          'Cần xác nhận chế độ ghép hàng.',
        ),
      );
    }
    if (!config.policyConfirmed) {
      blockers.add(
        const WorkflowIssue(
          'POLICY_CONFIRMATION_REQUIRED',
          'Cần xác nhận chính sách cho từng cột.',
        ),
      );
    }
    if (!config.directionConfirmed) {
      blockers.add(
        const WorkflowIssue(
          'DIRECTION_CONFIRMATION_REQUIRED',
          'Cần xác nhận chiều so sánh.',
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
        const WorkflowIssue(
          'KEY_INVALID',
          'Khóa cần là tuple cột IDENTIFIER, không trim hoặc tolerance.',
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
          const WorkflowIssue(
            'MAPPING_INVALID',
            'Ánh xạ phải là 1:1 giữa các Field ID hiện hành.',
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
          const WorkflowIssue(
            'POLICY_INVALID',
            'Thiếu hoặc sai cấu hình kiểu dữ liệu, locale hoặc tolerance.',
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
      issue = const WorkflowIssue(
        'RETRY_LIMIT',
        'Đã hết số lần thử. Hãy kiểm tra lại cấu hình.',
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
    phase = 'Xác thực cấu hình';
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
          throw const WorkflowIssue(
            'PROGRESS_INVALID',
            'Tiến trình tác vụ không hợp lệ.',
          );
        }
        phase = p;
        progressDone = done;
        progressTotal = total;
        _emit();
      });
      if (!current()) return;
      if (!identical(output.plan, plan) || output.id.isEmpty) {
        throw const WorkflowIssue(
          'RESULT_BINDING_INVALID',
          'Kết quả không thuộc cấu hình hiện hành.',
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
      issue = const WorkflowIssue(
        'RESULT_NOT_CURRENT',
        'Cần so sánh lại trước khi xuất.',
      );
      _emit();
      return;
    }
    if (!exporter.supports(request.kind)) {
      issue = const WorkflowIssue(
        'EXPORT_CAPABILITY_DISABLED',
        'Định dạng này chưa có bộ xuất được kiểm chứng trên mobile.',
      );
      _emit();
      return;
    }
    if (_exportAttempts >= maxAttempts) {
      issue = const WorkflowIssue(
        'RETRY_LIMIT',
        'Đã hết số lần thử xuất trong phiên này.',
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
        throw const WorkflowIssue(
          'RESULT_NOT_CURRENT',
          'Kết quả đã mất hiệu lực; cần so sánh lại.',
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
        issue = const WorkflowIssue(
          'CLEANUP_FAILED',
          'Không thể hoàn tất dọn dữ liệu tạm.',
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
        issue: const WorkflowIssue(
          'INP-ERR-018',
          'Nguồn khôi phục cần được xác thực lại.',
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
