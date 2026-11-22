import 'package:dytava/app/workflow_composition.dart';
import 'package:dytava/domain/smart_proposal_engine.dart';
import 'package:dytava/domain/workflow.dart';
import 'package:dytava/main.dart';
import 'package:excelcompare_core/excelcompare_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide ComparisonResult;

Future<void> tap(WidgetTester tester, String text) async {
  final target = find.text(text);
  await tester.scrollUntilVisible(
    target,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  group('SmartProposalEngine unit tests', () {
    late InputSnapshot snapshotA;
    late InputSnapshot snapshotB;

    setUp(() {
      snapshotA = InputSnapshot(
        id: 'snap-a',
        binding: const ImportBinding('art-a', 1, 0, 1),
        fields: const [
          TableField('id', 'Mã sản phẩm (id)'),
          TableField('amount', 'Số lượng (amount)'),
          TableField('notes', 'Ghi chú (notes)'),
        ],
        records: [
          TableRecord('r1', 0, const {
            'id': SourceCell(CellKind.text, rawLexeme: 'SP001'),
            'amount': SourceCell(CellKind.number, rawLexeme: '10.5'),
            'notes': SourceCell(CellKind.text, rawLexeme: 'Hàng mới'),
          }, const {}),
          TableRecord('r2', 1, const {
            'id': SourceCell(CellKind.text, rawLexeme: 'SP002'),
            'amount': SourceCell(CellKind.number, rawLexeme: '25.0'),
            'notes': SourceCell(CellKind.text, rawLexeme: 'Tồn kho'),
          }, const {}),
        ],
        fullValidation: true,
        ocrReviewed: true,
      );

      snapshotB = InputSnapshot(
        id: 'snap-b',
        binding: const ImportBinding('art-b', 1, 0, 1),
        fields: const [
          TableField('id', 'Mã sản phẩm (id)'),
          TableField('amount', 'Số lượng (amount)'),
          TableField('notes', 'Ghi chú (notes)'),
        ],
        records: [
          TableRecord('r1', 0, const {
            'id': SourceCell(CellKind.text, rawLexeme: 'SP001'),
            'amount': SourceCell(CellKind.number, rawLexeme: '10,5'),
            'notes': SourceCell(CellKind.text, rawLexeme: 'Hàng mới'),
          }, const {}),
          TableRecord('r2', 1, const {
            'id': SourceCell(CellKind.text, rawLexeme: 'SP002'),
            'amount': SourceCell(CellKind.number, rawLexeme: '25,0'),
            'notes': SourceCell(CellKind.text, rawLexeme: 'Tồn kho'),
          }, const {}),
        ],
        fullValidation: true,
        ocrReviewed: true,
      );
    });

    test('compareFiles proposes KEY mode when unique key column exists', () {
      final proposal = SmartProposalEngine.analyze(
        snapshotA,
        snapshotB,
        taskMode: ComparisonTaskMode.compareFiles,
      );

      expect(proposal.taskMode, ComparisonTaskMode.compareFiles);
      expect(proposal.mode, MatchingMode.key);
      expect(proposal.keys, contains('id'));
      expect(proposal.mappings.length, 3);
      expect(proposal.rules['id']?.type, SemanticType.identifier);
      expect(proposal.rules['amount']?.type, SemanticType.decimal);
      expect(proposal.isHighConfidence, isTrue);
      expect(proposal.requiresExplicitConfirmation, isFalse);

      final config = SmartProposalEngine.toConfiguration(proposal);
      expect(config.mappingConfirmed, isTrue);
      expect(config.modeConfirmed, isTrue);
      expect(config.policyConfirmed, isTrue);
      expect(config.directionConfirmed, isTrue);
    });

    test('compareColumns proposes single target column comparison', () {
      final proposal = SmartProposalEngine.analyze(
        snapshotA,
        snapshotB,
        taskMode: ComparisonTaskMode.compareColumns,
      );

      expect(proposal.taskMode, ComparisonTaskMode.compareColumns);
      expect(proposal.mappings.length, 1);
      expect(proposal.mappings.first.fieldA, 'amount');
      expect(proposal.mappings.first.fieldB, 'amount');
      expect(proposal.mode, MatchingMode.positional);
      expect(proposal.isHighConfidence, isTrue);
    });

    test('reconcile proposes key match with value column without VLOOKUP', () {
      final proposal = SmartProposalEngine.analyze(
        snapshotA,
        snapshotB,
        taskMode: ComparisonTaskMode.reconcile,
      );

      expect(proposal.taskMode, ComparisonTaskMode.reconcile);
      expect(proposal.mode, MatchingMode.key);
      expect(proposal.keys, contains('id'));
      expect(proposal.reconcileKeyColumn, 'id');
      expect(proposal.reconcileValueColumn, 'amount');
      expect(
        proposal.mappings.map((m) => m.fieldA),
        containsAll(['id', 'amount']),
      );
      expect(proposal.isHighConfidence, isTrue);
    });

    test('requiresExplicitConfirmation when key column has duplicates', () {
      final duplicateSnapshotA = InputSnapshot(
        id: 'snap-dup',
        binding: const ImportBinding('art-dup', 1, 0, 1),
        fields: const [TableField('id', 'id'), TableField('val', 'val')],
        records: [
          TableRecord('r1', 0, const {
            'id': SourceCell(CellKind.text, rawLexeme: 'DUP'),
            'val': SourceCell(CellKind.text, rawLexeme: 'A'),
          }, const {}),
          TableRecord('r2', 1, const {
            'id': SourceCell(CellKind.text, rawLexeme: 'DUP'),
            'val': SourceCell(CellKind.text, rawLexeme: 'B'),
          }, const {}),
        ],
        fullValidation: true,
        ocrReviewed: true,
      );

      final proposal = SmartProposalEngine.analyze(
        duplicateSnapshotA,
        duplicateSnapshotA,
        taskMode: ComparisonTaskMode.reconcile,
      );

      expect(proposal.requiresExplicitConfirmation, isTrue);
      expect(proposal.isHighConfidence, isFalse);
      expect(proposal.confidenceScore, lessThan(0.85));
    });
  });

  testWidgets('Quick Compare analyzes both files before running', (tester) async {
    final flow = createDemoWorkflow();
    addTearDown(flow.dispose);
    await tester.pumpWidget(ExcelCompareApp(controller: flow));
    await tester.tap(find.byTooltip('Compare files'));
    await tester.pumpAndSettle();
    await tap(tester, 'Use sample files ›');
    expect(flow.inputsReady, isTrue);
    expect(flow.result, isNull);
    await tap(tester, 'Compare files');
    expect(flow.proposal, isNotNull);
    expect(flow.resultCurrent, isTrue);
    expect(find.text('RESULTS READY'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
