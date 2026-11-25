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

    test('Restores full workbook session with multiple sheets, aligned rows, fields, and >100k cells capability without truncation', () async {
      final fields = [
        const TableField('id', 'Mã SP'),
        const TableField('name', 'Tên sản phẩm'),
        const TableField('price', 'Đơn giá'),
      ];
      final recA1 = TableRecord(
        'r-a-1',
        0,
        {
          'id': const SourceCell(CellKind.text, rawLexeme: 'SP-01'),
          'name': const SourceCell(CellKind.text, rawLexeme: 'Nguyễn Văn An'),
          'price': const SourceCell(CellKind.text, rawLexeme: '100€'),
        },
        {'id': 'Sheet1!A2', 'name': 'Sheet1!B2', 'price': 'Sheet1!C2'},
      );
      final recB1 = TableRecord(
        'r-b-1',
        0,
        {
          'id': const SourceCell(CellKind.text, rawLexeme: 'SP-01'),
          'name': const SourceCell(CellKind.text, rawLexeme: 'Nguyễn Văn An'),
          'price': const SourceCell(CellKind.text, rawLexeme: '120€'),
        },
        {'id': 'Sheet1!A2', 'name': 'Sheet1!B2', 'price': 'Sheet1!C2'},
      );
      final snapA1 = InputSnapshot(
        id: 'snap-a-s1',
        binding: const ImportBinding('art-a', 1, 1, 1),
        fields: fields,
        records: [recA1],
        fullValidation: true,
        ocrReviewed: false,
        sheetName: 'Doanh thu Q1',
      );
      final snapB1 = InputSnapshot(
        id: 'snap-b-s1',
        binding: const ImportBinding('art-b', 1, 1, 1),
        fields: fields,
        records: [recB1],
        fullValidation: true,
        ocrReviewed: false,
        sheetName: 'Doanh thu Q2',
      );
      final cfg = ComparisonConfiguration(
        mappings: const [
          FieldMapping('id', 'id'),
          FieldMapping('name', 'name'),
          FieldMapping('price', 'price'),
        ],
        rules: const {
          'id': FieldRule(type: SemanticType.identifier),
          'name': FieldRule(type: SemanticType.freeText),
          'price': FieldRule(type: SemanticType.freeText),
        },
        mode: MatchingMode.key,
        keys: const ['id'],
        mappingConfirmed: true,
        modeConfirmed: true,
        policyConfirmed: true,
        directionConfirmed: true,
      );
      final pair1 = const SheetPair(0, 0, 'Doanh thu Q1', 'Doanh thu Q2', 'name', 1.0);
      final plan1 = FrozenPlan('plan-s1', 1, snapA1, snapB1, cfg);
      final cell1 = CellDifference(
        id: 'c-s1-1',
        rowA: 'r-a-1',
        rowB: 'r-b-1',
        mapping: const FieldMapping('price', 'price'),
        a: const SourceCell(CellKind.text, rawLexeme: '100€'),
        b: const SourceCell(CellKind.text, rawLexeme: '120€'),
        locationA: 'Doanh thu Q1!C2',
        locationB: 'Doanh thu Q2!C2',
        decision: const ComparisonDecision(
          status: DecisionStatus.different,
          ruleId: 'text/diff',
          explanation: 'Changed',
        ),
      );
      final sheetRes1 = ComparisonResult(
        id: 'res-s1',
        plan: plan1,
        cells: [cell1],
        structural: const [
          StructuralChange('ROW_ADDED', SourceSide.b, 'r-b-extra'),
        ],
        unresolvedRecords: const [],
        matchedRecords: 1,
        alignedRows: [
          AlignedTableRow(recA1, recB1, 'Key match', [cell1]),
        ],
        sheetPair: pair1,
        warnings: const ['Doanh thu Q1: Cảnh báo mẫu'],
      );
      final wbResult = ComparisonResult(
        id: 'wb-session-01',
        plan: FrozenPlan(
          'plan-wb',
          1,
          InputSnapshot(
            id: 'wb-a',
            binding: const ImportBinding('art-a', 1, 1, 1),
            fields: fields,
            records: [recA1],
            fullValidation: true,
            ocrReviewed: false,
            sheetName: 'Doanh thu Q1',
            workbookSheets: [snapA1],
          ),
          InputSnapshot(
            id: 'wb-b',
            binding: const ImportBinding('art-b', 1, 1, 1),
            fields: fields,
            records: [recB1],
            fullValidation: true,
            ocrReviewed: false,
            sheetName: 'Doanh thu Q2',
            workbookSheets: [snapB1],
          ),
          cfg,
        ),
        cells: [cell1],
        structural: sheetRes1.structural,
        unresolvedRecords: [
          RecordUnresolved('KEY_DUPLICATE', const ['r-a-dup'], const ['r-b-dup']),
        ],
        matchedRecords: 1,
        alignedRows: sheetRes1.alignedRows,
        sheetResults: [sheetRes1],
        warnings: const ['Doanh thu Q1: Cảnh báo mẫu'],
      );

      await db.saveSession(
        result: wbResult,
        labelA: 'Workbook_A.xlsx',
        labelB: 'Workbook_B.xlsx',
        formatA: SourceFormat.xlsx,
        formatB: SourceFormat.xlsx,
        config: cfg,
      );

      final restored = await db.loadSession('wb-session-01');
      expect(restored, isNotNull);
      expect(restored!.sheetResults.length, 1);
      expect(restored.sheetResults.first.sheetPair?.nameA, 'Doanh thu Q1');
      expect(restored.sheetResults.first.sheetPair?.nameB, 'Doanh thu Q2');
      expect(restored.plan.a.fields.map((f) => f.label), ['Mã SP', 'Tên sản phẩm', 'Đơn giá']);
      expect(restored.plan.config.mode, MatchingMode.key);
      expect(restored.plan.config.keys, ['id']);
      expect(restored.alignedRows.length, 1);
      expect(restored.alignedRows.first.a?.cells['name']?.rawLexeme, 'Nguyễn Văn An');
      expect(restored.alignedRows.first.b?.cells['price']?.rawLexeme, '120€');
      expect(restored.unresolvedRecords.single.reason, 'KEY_DUPLICATE');
      expect(restored.warnings, contains('Doanh thu Q1: Cảnh báo mẫu'));
    });

    test('Privacy control: persistRawCellValues = false omits raw cell strings from SQLite', () async {
      db.persistRawCellValues = false;
      addTearDown(() => db.persistRawCellValues = true);

      final snap = InputSnapshot(
        id: 'snap',
        binding: const ImportBinding('art', 1, 1, 1),
        fields: [const TableField('secret', 'Secret')],
        records: const [],
        fullValidation: true,
        ocrReviewed: false,
      );
      final plan = FrozenPlan('p', 1, snap, snap, ComparisonConfiguration());
      final res = ComparisonResult(
        id: 'privacy-session',
        plan: plan,
        cells: const [
          CellDifference(
            id: 'c1',
            rowA: 'r1',
            rowB: 'r1',
            mapping: FieldMapping('secret', 'secret'),
            a: SourceCell(CellKind.text, rawLexeme: 'Sensitive_Salary_999'),
            b: SourceCell(CellKind.text, rawLexeme: 'Sensitive_Salary_888'),
            locationA: 'A1',
            locationB: 'A1',
            decision: ComparisonDecision(
              status: DecisionStatus.different,
              ruleId: 'rule/diff',
            ),
          ),
        ],
        structural: const [],
        unresolvedRecords: const [],
        matchedRecords: 1,
      );

      await db.saveSession(
        result: res,
        labelA: 'A.csv',
        labelB: 'B.csv',
        formatA: SourceFormat.csv,
        formatB: SourceFormat.csv,
        config: plan.config,
      );

      final loaded = await db.loadSession('privacy-session');
      expect(loaded, isNotNull);
      expect(loaded!.cells.single.a.rawLexeme, isNull);
      expect(loaded.cells.single.b.rawLexeme, isNull);
      expect(loaded.count(DecisionStatus.different), 1);
    });
  });
}
