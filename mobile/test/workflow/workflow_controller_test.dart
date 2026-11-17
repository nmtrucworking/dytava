import 'dart:async';
import 'dart:convert';

import 'package:dytava/application/workflow_controller.dart';
import 'package:dytava/domain/workflow.dart';
import 'package:dytava/infrastructure/demo/demo_workflow_ports.dart';
import 'package:excelcompare_core/excelcompare_core.dart';
import 'package:flutter_test/flutter_test.dart' hide ComparisonResult;

ComparisonConfiguration confirmed({
  ComparisonDirection direction = ComparisonDirection.aToB,
}) => ComparisonConfiguration(
  mappings: const [FieldMapping('id', 'id'), FieldMapping('amount', 'amount')],
  rules: const {
    'id': FieldRule(type: SemanticType.identifier),
    'amount': FieldRule(type: SemanticType.decimal),
  },
  mappingConfirmed: true,
  modeConfirmed: true,
  policyConfirmed: true,
  directionConfirmed: true,
  mode: MatchingMode.key,
  keys: ['id'],
  direction: direction,
);
WorkflowController create({
  InputPort? input,
  ComparisonPort? compare,
  ExportPort? export,
}) => WorkflowController(
  input: input ?? DemoInputPort(),
  comparator: compare ?? DemoComparisonPort(),
  exporter: export ?? DemoExportPort(),
);
Future<void> confirmSource(
  WorkflowController f,
  SourceSide s, {
  Set<String> reviewed = const {},
}) => f.confirmImport(
  s,
  expectedBinding: f.slot(s).binding,
  reviewedCells: reviewed,
);
Future<void> ready(WorkflowController f) async {
  for (final s in SourceSide.values) {
    await f.selectSource(s, SourceFormat.csv, 'fixture:${s.name}', 'same.csv');
    await f.importSource(s);
    expect(f.slot(s).state, InputState.needsReview);
    await confirmSource(f, s);
    expect(f.slot(s).ready, isTrue);
  }
  f.configure(confirmed());
}

InputSnapshot snapshot(ImportBinding b, {bool complete = true}) =>
    InputSnapshot(
      id: '${b.artifactId}-snapshot',
      binding: b,
      fullValidation: complete,
      ocrReviewed: false,
      fields: const [TableField('id', 'id')],
      records: [],
    );

final class HeldInput implements InputPort {
  final entered = Completer<ImportBinding>();
  final release = Completer<ImportOutcome>();
  @override
  Future<ImportOutcome> importSource(
    SourceArtifact a,
    ImportBinding b,
    ImportConfiguration c,
    Cancellation cancel,
    void Function() onParsing,
  ) async {
    onParsing();
    entered.complete(b);
    return release.future;
  }
}

final class HeldComparison implements ComparisonPort {
  final entered = Completer<FrozenPlan>();
  final release = Completer<void>();
  @override
  List<WorkflowIssue> get startBlockers => [];
  @override
  Future<ComparisonResult> compare(
    FrozenPlan p,
    Cancellation c,
    void Function(String, int, int?) progress,
  ) async {
    entered.complete(p);
    await release.future;
    return ComparisonResult(
      id: 'late',
      plan: p,
      cells: [],
      structural: [],
      unresolvedRecords: [],
      matchedRecords: 0,
    );
  }
}

final class HeldExport implements ExportPort {
  final entered = Completer<void>();
  final release = Completer<void>();
  final cleanup = Completer<void>();
  bool published = false;
  @override
  bool supports(ExportKind k) => true;
  @override
  Future<PreparedExport> render(
    ComparisonResult r,
    ExportRequest request,
    Cancellation c,
  ) async {
    entered.complete();
    await release.future;
    return const PreparedExport('{}', 0);
  }

  @override
  Future<void> verify(PreparedExport p, Cancellation c) async {}
  @override
  Future<ExportReceipt> publish(
    PreparedExport p,
    String id,
    Cancellation c,
  ) async {
    published = true;
    return ExportReceipt(id, '{}', previewOnly: true);
  }

  @override
  Future<void> discard(PreparedExport? p) => cleanup.future;
}

final class TransientInput implements InputPort {
  int attempts = 0;
  @override
  Future<ImportOutcome> importSource(
    SourceArtifact a,
    ImportBinding b,
    ImportConfiguration config,
    Cancellation cancel,
    void Function() onParsing,
  ) async {
    attempts++;
    throw const WorkflowIssue(
      'TEMPORARILY_UNAVAILABLE',
      'Thử lại nguồn.',
      retryable: true,
    );
  }
}

void main() {
  test(
    'downstream route guards require current snapshots and completed result',
    () {
      final f = create();
      addTearDown(f.dispose);
      for (final s in [
        WorkflowScreen.mapping,
        WorkflowScreen.policy,
        WorkflowScreen.results,
        WorkflowScreen.detail,
        WorkflowScreen.export,
      ]) {
        expect(f.navigate(s), isFalse);
      }
      expect(
        f.startBlockers.map((i) => i.code),
        contains('DIRECTION_CONFIRMATION_REQUIRED'),
      );
    },
  );
  test(
    'same-named sources are independent; missing direction blocks START',
    () async {
      final f = create();
      addTearDown(f.dispose);
      await ready(f);
      expect(
        f.slot(SourceSide.a).artifact!.id,
        isNot(f.slot(SourceSide.b).artifact!.id),
      );
      expect(f.startBlockers, isEmpty);
      f.configure(f.config.copyWith(directionConfirmed: false));
      await f.runComparison();
      expect(f.jobState, JobState.created);
      expect(f.issue!.code, 'DIRECTION_CONFIRMATION_REQUIRED');
    },
  );
  test('four verdicts, raw/canonical and structural counts reconcile; late cancel is harmless', () async {
    final f = create();
    addTearDown(f.dispose);
    await ready(f);
    await f.runComparison();
    final r = f.result!;
    expect(f.jobState, JobState.completed);
    expect(r.cells.length, 8);
    expect(r.count(DecisionStatus.exact), 5);
    expect(r.count(DecisionStatus.equivalent), 1);
    expect(r.count(DecisionStatus.different), 1);
    expect(r.count(DecisionStatus.unresolved), 1);
    expect(r.structural.single.kind, 'ROW_ADDED');
    expect(r.agreementRate, 0.75);
    final equivalent = r.cells.singleWhere(
      (c) => c.decision.status == DecisionStatus.equivalent,
    );
    expect(equivalent.a.rawLexeme, '8.5');
    expect(equivalent.b.rawLexeme, '8,5');
    expect(equivalent.decision.left!.label, '8.5');
    await f.cancelComparison();
    expect(f.jobState, JobState.completed);
    expect(() => r.cells.clear(), throwsUnsupportedError);
  });
  test('direction preserves inputs, invalidates query/export, then reverses added/removed', () async {
    final f = create();
    addTearDown(f.dispose);
    await ready(f);
    await f.runComparison();
    final input = f.slot(SourceSide.a).snapshot;
    f.configure(confirmed(direction: ComparisonDirection.bToA));
    expect(f.slot(SourceSide.a).snapshot, same(input));
    expect(f.visibleCells, isEmpty);
    expect(f.navigate(WorkflowScreen.export), isFalse);
    await f.exportResult(
      const ExportRequest(
        ExportKind.jsonReport,
        ExportSelection.fullComparison,
      ),
    );
    expect(f.issue!.code, 'RESULT_NOT_CURRENT');
    await f.runComparison();
    expect(f.result!.structural.single.kind, 'ROW_REMOVED');
  });
  test('change A config keeps B ready and invalidates mapping', () async {
    final f = create();
    addTearDown(f.dispose);
    await ready(f);
    final b = f.slot(SourceSide.b).snapshot;
    await f.changeImportConfig(SourceSide.a, const ImportConfiguration());
    expect(f.slot(SourceSide.a).state, InputState.selected);
    expect(f.slot(SourceSide.b).snapshot, same(b));
    expect(f.slot(SourceSide.b).ready, isTrue);
    expect(f.config.mappingConfirmed, isFalse);
  });
  test('late import completion after replacement is discarded', () async {
    final p = HeldInput();
    final f = create(input: p);
    addTearDown(f.dispose);
    await f.selectSource(SourceSide.a, SourceFormat.csv, 'old', 'data.csv');
    final importing = f.importSource(SourceSide.a);
    final b = await p.entered.future;
    final replacing = f.selectSource(
      SourceSide.a,
      SourceFormat.csv,
      'new',
      'data.csv',
    );
    expect(f.slot(SourceSide.a).artifact!.id, isNot(b.artifactId));
    p.release.complete(ImportOutcome.ready(snapshot(b)));
    await Future.wait([importing, replacing]);
    expect(f.slot(SourceSide.a).snapshot, isNull);
    expect(f.slot(SourceSide.a).state, InputState.selected);
  });
  test('cancel waits for stopped import and discards late snapshot', () async {
    final p = HeldInput();
    final f = create(input: p);
    addTearDown(f.dispose);
    await f.selectSource(SourceSide.a, SourceFormat.csv, 'ref', 'data.csv');
    final importing = f.importSource(SourceSide.a);
    final b = await p.entered.future;
    var stopped = false;
    final cancelling = f.cancelImport(SourceSide.a).then((_) => stopped = true);
    await Future<void>.delayed(Duration.zero);
    expect(stopped, isFalse);
    expect(f.slot(SourceSide.a).cancelling, isTrue);
    p.release.complete(ImportOutcome.ready(snapshot(b)));
    await Future.wait([importing, cancelling]);
    expect(f.slot(SourceSide.a).state, InputState.cancelled);
    expect(f.slot(SourceSide.a).snapshot, isNull);
  });
  test('sample-only import cannot become PREVIEW_READY', () async {
    final p = HeldInput();
    final f = create(input: p);
    addTearDown(f.dispose);
    await f.selectSource(SourceSide.a, SourceFormat.csv, 'ref', 'data.csv');
    final importing = f.importSource(SourceSide.a);
    final b = await p.entered.future;
    p.release.complete(ImportOutcome.ready(snapshot(b, complete: false)));
    await importing;
    expect(f.slot(SourceSide.a).state, InputState.failed);
    expect(f.slot(SourceSide.a).issue!.code, 'SNAPSHOT_NOT_VALIDATED');
  });
  test(
    'nonbijective mapping, stale IDs and invalid policy fail closed',
    () async {
      final f = create();
      addTearDown(f.dispose);
      await ready(f);
      f.configure(
        confirmed().copyWith(
          mappings: const [
            FieldMapping('id', 'id'),
            FieldMapping('amount', 'id'),
          ],
        ),
      );
      expect(f.startBlockers.map((i) => i.code), contains('MAPPING_INVALID'));
      f.configure(
        confirmed().copyWith(mappings: const [FieldMapping('old', 'id')]),
      );
      expect(f.startBlockers.map((i) => i.code), contains('MAPPING_INVALID'));
      f.configure(
        confirmed().copyWith(
          rules: const {
            'id': FieldRule(type: SemanticType.identifier),
            'amount': FieldRule(type: SemanticType.decimal, tolerance: '-1'),
          },
        ),
      );
      expect(f.startBlockers.map((i) => i.code), contains('POLICY_INVALID'));
      f.configure(
        confirmed().copyWith(
          rules: const {
            'id': FieldRule(type: SemanticType.identifier, trim: true),
            'amount': FieldRule(type: SemanticType.decimal),
          },
        ),
      );
      expect(f.startBlockers.map((i) => i.code), contains('KEY_INVALID'));
      await f.runComparison();
      expect(f.result, isNull);
    },
  );
  test('one image only; all OCR cells need current review receipts', () async {
    final f = create();
    addTearDown(f.dispose);
    await f.selectSource(
      SourceSide.a,
      SourceFormat.png,
      'fixture:image-a',
      'image.png',
    );
    await f.selectSource(
      SourceSide.b,
      SourceFormat.png,
      'fixture:image-a',
      'image.png',
    );
    expect(f.slot(SourceSide.b).artifact, isNull);
    expect(f.issue!.code, 'IMAGE_PAIR_UNSUPPORTED');
    await f.importSource(SourceSide.a);
    final oldBinding = f.slot(SourceSide.a).binding;
    final review = f.slot(SourceSide.a).review!;
    await confirmSource(f, SourceSide.a, reviewed: {review.cells.first.id});
    expect(f.slot(SourceSide.a).state, InputState.needsReview);
    await confirmSource(
      f,
      SourceSide.a,
      reviewed: review.cells.map((c) => c.id).toSet(),
    );
    expect(f.slot(SourceSide.a).ready, isTrue);
    await f.changeImportConfig(
      SourceSide.a,
      const ImportConfiguration(ocrRevision: 1),
    );
    await f.importSource(SourceSide.a);
    await f.confirmImport(
      SourceSide.a,
      expectedBinding: oldBinding,
      reviewedCells: review.cells.map((c) => c.id).toSet(),
    );
    expect(f.slot(SourceSide.a).state, InputState.needsReview);
    expect(f.slot(SourceSide.a).config.reviewedCells, isEmpty);
  });
  test('unverified capability/profile never creates a job', () async {
    final f = create(compare: UnavailableComparisonPort());
    addTearDown(f.dispose);
    await ready(f);
    await f.runComparison();
    expect(
      f.startBlockers.map((i) => i.code),
      containsAll(['CAPABILITY_NOT_VERIFIED', 'RESOURCE_PROFILE_NOT_ENABLED']),
    );
    expect(f.jobState, JobState.created);
  });
  test('late comparison completion after cancel cannot publish', () async {
    final p = HeldComparison();
    final f = create(compare: p);
    addTearDown(f.dispose);
    await ready(f);
    final running = f.runComparison();
    await p.entered.future;
    final cancelling = f.cancelComparison();
    expect(f.jobState, JobState.cancelling);
    p.release.complete();
    await Future.wait([running, cancelling]);
    expect(f.jobState, JobState.cancelled);
    expect(f.resultCurrent, isFalse);
    expect(f.result, isNull);
  });
  test(
    'revocation during comparison keeps B ready and blocks publication',
    () async {
      final p = HeldComparison();
      final f = create(compare: p);
      addTearDown(f.dispose);
      await ready(f);
      final running = f.runComparison();
      await p.entered.future;
      await f.revokeSource(SourceSide.a);
      p.release.complete();
      await running;
      expect(f.validity, ResultValidity.revoked);
      expect(f.result, isNull);
      expect(f.slot(SourceSide.b).ready, isTrue);
    },
  );
  test('JSON preview has explicit scope and no access refs; unsupported PDF is blocked', () async {
    final f = create();
    addTearDown(f.dispose);
    await ready(f);
    await f.runComparison();
    final stages = <ExportState?>[];
    f.addListener(() => stages.add(f.exportState));
    await f.exportResult(
      const ExportRequest(
        ExportKind.jsonReport,
        ExportSelection.differencesOnly,
      ),
    );
    expect(
      stages,
      containsAllInOrder([
        ExportState.requested,
        ExportState.validating,
        ExportState.rendering,
        ExportState.verifying,
        ExportState.publishing,
        ExportState.completed,
      ]),
    );
    expect(f.receipt!.previewOnly, isTrue);
    final report = jsonDecode(f.receipt!.previewText) as Map;
    expect(report['selected_cell_count'], 2);
    expect((report['full_counts'] as Map)['exact'], 5);
    expect(f.receipt!.previewText, isNot(contains('fixture:a')));
    expect(f.receipt!.previewText, isNot(contains('privateRef')));
    await f.cancelExport();
    expect(f.exportState, ExportState.completed);
    await f.exportResult(
      const ExportRequest(
        ExportKind.mergedDiffPdf,
        ExportSelection.fullComparison,
      ),
    );
    expect(f.issue!.code, 'EXPORT_CAPABILITY_DISABLED');
  });
  test(
    'cancel export waits for cleanup, keeps result, never publishes partial',
    () async {
      final p = HeldExport();
      final f = create(export: p);
      addTearDown(f.dispose);
      await ready(f);
      await f.runComparison();
      final exporting = f.exportResult(
        const ExportRequest(
          ExportKind.jsonReport,
          ExportSelection.fullComparison,
        ),
      );
      await p.entered.future;
      var stopped = false;
      final cancelling = f.cancelExport().then((_) => stopped = true);
      p.release.complete();
      await Future<void>.delayed(Duration.zero);
      expect(f.exportState, ExportState.cancelling);
      expect(stopped, isFalse);
      expect(p.published, isFalse);
      p.cleanup.complete();
      await Future.wait([exporting, cancelling]);
      expect(f.exportState, ExportState.cancelled);
      expect(f.receipt, isNull);
      expect(f.resultCurrent, isTrue);
    },
  );
  test('invalidation during export prevents publish', () async {
    final p = HeldExport();
    final f = create(export: p);
    addTearDown(f.dispose);
    await ready(f);
    await f.runComparison();
    final exporting = f.exportResult(
      const ExportRequest(
        ExportKind.jsonReport,
        ExportSelection.fullComparison,
      ),
    );
    await p.entered.future;
    f.configure(confirmed(direction: ComparisonDirection.bToA));
    p.release.complete();
    p.cleanup.complete();
    await exporting;
    expect(p.published, isFalse);
    expect(f.receipt, isNull);
    expect(f.resultCurrent, isFalse);
  });
  test('close clears raw fixture state; restore only selects refs and requires validation', () async {
    final f = create();
    addTearDown(f.dispose);
    await ready(f);
    await f.runComparison();
    final a = f.slot(SourceSide.a).artifact!;
    await f.closeSession();
    expect(f.result, isNull);
    expect(f.slot(SourceSide.a).artifact, isNull);
    await f.restoreSources({SourceSide.a: a}, interruptedJob: true);
    expect(f.jobState, JobState.interrupted);
    expect(f.slot(SourceSide.a).state, InputState.selected);
    expect(f.slot(SourceSide.a).issue!.code, 'INP-ERR-018');
    expect(f.inputsReady, isFalse);
  });
  test('transient import retries stop at finite limit', () async {
    final p = TransientInput();
    final f = create(input: p);
    addTearDown(f.dispose);
    await f.selectSource(
      SourceSide.a,
      SourceFormat.csv,
      'private-ref',
      'data.csv',
    );
    for (var i = 0; i < 5; i++) {
      await f.importSource(SourceSide.a);
    }
    expect(p.attempts, 3);
    expect(f.issue!.code, 'RETRY_LIMIT');
    expect(f.slot(SourceSide.a).state, InputState.failed);
  });

  test('failed cleanup cannot be acknowledged as CANCELLED', () async {
    final p = HeldExport();
    final f = create(export: p);
    addTearDown(f.dispose);
    await ready(f);
    await f.runComparison();
    final exporting = f.exportResult(
      const ExportRequest(
        ExportKind.jsonReport,
        ExportSelection.fullComparison,
      ),
    );
    await p.entered.future;
    final cancelling = f.cancelExport();
    p.release.complete();
    await Future<void>.delayed(Duration.zero);
    p.cleanup.completeError(StateError('sensitive-provider-ref'));
    await Future.wait([exporting, cancelling]);
    expect(f.exportState, ExportState.failed);
    expect(f.receipt, isNull);
    expect(f.issue!.code, 'CLEANUP_FAILED');
    expect(f.issue!.message, isNot(contains('sensitive-provider-ref')));
  });
}
