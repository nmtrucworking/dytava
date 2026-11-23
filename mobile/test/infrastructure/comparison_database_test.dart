import 'package:excelcompare_core/excelcompare_core.dart';
import 'package:flutter_test/flutter_test.dart' hide ComparisonResult;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dytava/domain/workflow.dart';
import 'package:dytava/infrastructure/database/comparison_database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('ComparisonDatabase SQLite Engine', () {
    late ComparisonDatabase db;

    setUp(() async {
      db = ComparisonDatabase.instance;
      await db.init(
        customPath: inMemoryDatabasePath,
        customFactory: databaseFactoryFfi,
      );
      await db.clearAll();
    });

    tearDown(() async {
      await db.clearAll();
      await db.close();
    });

    test('Saves comparison session with chunked batching and queries windowed cells', () async {
      final snapA = InputSnapshot(
        id: 'snap-a',
        binding: const ImportBinding('art-a', 1, 1, 1),
        fields: [const TableField('id', 'ID'), const TableField('val', 'Val')],
        records: const [],
        fullValidation: true,
        ocrReviewed: false,
      );
      final snapB = InputSnapshot(
        id: 'snap-b',
        binding: const ImportBinding('art-b', 1, 1, 1),
        fields: [const TableField('id', 'ID'), const TableField('val', 'Val')],
        records: const [],
        fullValidation: true,
        ocrReviewed: false,
      );

      final plan = FrozenPlan(
        'plan-01',
        1,
        snapA,
        snapB,
        ComparisonConfiguration(
          mappings: [
            const FieldMapping('id', 'id'),
            const FieldMapping('val', 'val'),
          ],
        ),
      );

      // Generate 2,500 cells to verify chunking (> 1,000 threshold)
      final generatedCells = List.generate(2500, (i) {
        final isDiff = i % 5 == 0;
        return CellDifference(
          id: 'cell-$i',
          rowA: 'row-a-$i',
          rowB: 'row-b-$i',
          mapping: const FieldMapping('val', 'val'),
          a: SourceCell(CellKind.text, rawLexeme: 'Val $i'),
          b: SourceCell(CellKind.text, rawLexeme: isDiff ? 'Changed $i' : 'Val $i'),
          locationA: 'Sheet1!B${i + 1}',
          locationB: 'Sheet1!B${i + 1}',
          decision: ComparisonDecision(
            status: isDiff ? DecisionStatus.different : DecisionStatus.exact,
            ruleId: isDiff ? 'rule/diff' : 'rule/exact',
            explanation: isDiff ? 'Values do not match' : 'Values match',
          ),
        );
      });

      final result = ComparisonResult(
        id: 'res-large-test',
        plan: plan,
        cells: generatedCells,
        structural: [
          const StructuralChange('ROW_ADDED', SourceSide.b, 'row-b-9999'),
        ],
        unresolvedRecords: const [],
        matchedRecords: 2500,
        alignedRows: [
          AlignedTableRow(null, null, 'Test row rationale', const []),
        ],
        durationMs: 120,
      );

      // Save to SQLite
      await db.saveSession(
        result: result,
        labelA: 'Sales_Q1.xlsx',
        labelB: 'Sales_Q2.xlsx',
        formatA: SourceFormat.xlsx,
        formatB: SourceFormat.xlsx,
        config: plan.config,
      );

      // 1. Verify summary query
      final sessions = await db.listRecentSessions();
      expect(sessions.length, 1);
      final s = sessions.first;
      expect(s.sessionId, 'res-large-test');
      expect(s.labelA, 'Sales_Q1.xlsx');
      expect(s.labelB, 'Sales_Q2.xlsx');
      expect(s.totalCells, 2500);
      expect(s.differentCount, 500);
      expect(s.exactCount, 2000);
      expect(s.isActive, true);

      // 2. Fast windowed paging query (limit 12)
      final page1 = await db.queryCells(
        sessionId: 'res-large-test',
        offset: 0,
        limit: 12,
      );
      expect(page1.length, 12);
      expect(page1.first.id, 'cell-0');
      expect(page1[1].id, 'cell-1');

      // 3. Filter query using indexed status
      final diffCells = await db.queryCells(
        sessionId: 'res-large-test',
        statusFilter: DecisionStatus.different,
        offset: 0,
        limit: 12,
      );
      expect(diffCells.length, 12);
      expect(diffCells.every((c) => c.decision.status == DecisionStatus.different), true);
      expect(diffCells.first.id, 'cell-0');
      expect(diffCells[1].id, 'cell-5');

      // 4. Count query
      final countDiff = await db.countCells(
        sessionId: 'res-large-test',
        statusFilter: DecisionStatus.different,
      );
      expect(countDiff, 500);

      // 5. Deletion
      await db.deleteSession('res-large-test');
      final afterDelete = await db.listRecentSessions();
      expect(afterDelete.isEmpty, true);
    });
  });
}
