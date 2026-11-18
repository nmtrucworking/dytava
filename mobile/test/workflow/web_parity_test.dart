import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart' hide ComparisonResult;
import 'package:excelcompare_core/excelcompare_core.dart';
import 'package:dytava/domain/workflow.dart';
import 'package:dytava/domain/word_difference.dart';
import 'package:dytava/infrastructure/mobile_comparison_port.dart';
import 'package:dytava/infrastructure/mobile_export_port.dart';
import 'package:dytava/infrastructure/file_upload_service.dart';
import 'package:dytava/app/workflow_composition.dart';

InputSnapshot table(
  String side,
  List<String> headers,
  List<List<String>> rows,
) => InputSnapshot(
  id: side,
  binding: ImportBinding(side, 1, 1, 1),
  fields: headers.map((h) => TableField(h, h)),
  fullValidation: true,
  ocrReviewed: false,
  records: [
    for (var i = 0; i < rows.length; i++)
      TableRecord(
        '$side-$i',
        i,
        {
          for (var c = 0; c < headers.length; c++)
            headers[c]: SourceCell(CellKind.text, rawLexeme: rows[i][c]),
        },
        {for (final h in headers) h: '$side!R${i + 2}/$h'},
      ),
  ],
);
FrozenPlan plan(
  InputSnapshot a,
  InputSnapshot b, {
  MatchingMode mode = MatchingMode.orderedSequence,
}) => FrozenPlan(
  'test',
  1,
  a,
  b,
  ComparisonConfiguration(
    mappings: [
      for (final h in a.fields.where((h) => b.fields.any((f) => f.id == h.id)))
        FieldMapping(h.id, h.id),
    ],
    rules: {
      for (final h in a.fields)
        h.id: const FieldRule(type: SemanticType.freeText, webAuto: true),
    },
    mode: mode,
    keys: mode == MatchingMode.key ? ['ID'] : [],
  ),
);
ComparisonResult compare(FrozenPlan p) => compareMobileTables(p, (_, _, _) {});

void main() {
  test('140 generated web cases preserve verdicts and rule IDs', () {
    final fixtures = jsonDecode(
      File('test/fixtures/web-cell-parity.json').readAsStringSync(),
    ) as List;
    for (final f in fixtures) {
      final p = f['policy'] as Map;
      final r =
          WebCellEngine(
            WebComparisonPolicy(
              trimText: p['trim_text'] ?? true,
              caseSensitiveText: p['case_sensitive_text'] ?? false,
              preserveLeadingZeros: p['preserve_leading_zeros'] ?? true,
              caseSensitiveIdentifier: p['case_sensitive_identifier'] ?? true,
              distinctNullZero: p['distinct_null_zero'] ?? true,
            ),
          ).compare(
            SourceCell(CellKind.text, rawLexeme: f['a']),
            SourceCell(CellKind.text, rawLexeme: f['b']),
            tolerance: (p['tolerance_abs'] as num? ?? 0).toDouble(),
          );
      expect(r.status.name.toUpperCase(), f['status'], reason: '$f');
      expect(r.ruleId, f['rule'], reason: '$f');
      expect(r.left?.label, f['normA'], reason: '$f');
      expect(r.right?.label, f['normB'], reason: '$f');
    }
    final percent = const WebCellEngine().compare(
      const SourceCell(CellKind.text, rawLexeme: '100%'),
      const SourceCell(CellKind.text, rawLexeme: '1'),
    );
    expect(percent.left?.label, '1');
    expect(percent.right?.label, '1');
  });
  test(
    'sequence keeps insertion in place, renumbering metadata and lineage',
    () {
      final p = plan(
        table(
          'A',
          ['No.', 'Date', 'Title'],
          [
            ['1', '2026-01-01', 'Brief'],
            ['2', '2026-02-01', 'Report'],
          ],
        ),
        table(
          'B',
          ['No.', 'Date', 'Title'],
          [
            ['1', '2026-01-01', 'Brief'],
            ['2', '2026-01-15', 'Review'],
            ['3', '2026-02-01', 'Report'],
          ],
        ),
      );
      final r = compare(p);
      expect(r.matchedRecords, 2);
      expect(r.structural.where((s) => s.kind == 'ROW_ADDED').length, 1);
      expect(r.count(DecisionStatus.different), 0);
      expect(r.count(DecisionStatus.equivalent), 1);
      expect(r.alignedRows[1].a, isNull);
      expect(r.alignedRows.last.a!.ordinal, 1);
      expect(r.alignedRows.last.b!.ordinal, 2);
      expect(r.cells.last.locationB, 'B!R4/Title');
    },
  );
  test('KEY supports reordered rows; blank or duplicate keys fail safely', () {
    final a = table(
      'A',
      ['ID', 'Value'],
      [
        ['01', 'x'],
        ['02', 'y'],
      ],
    );
    expect(
      compare(
        plan(
          a,
          table(
            'B',
            ['ID', 'Value'],
            [
              ['02', 'y'],
              ['01', 'x'],
            ],
          ),
          mode: MatchingMode.key,
        ),
      ).count(DecisionStatus.exact),
      4,
    );
    expect(
      () => compare(
        plan(
          a,
          table(
            'B',
            ['ID', 'Value'],
            [
              ['01', 'x'],
              ['01', 'y'],
            ],
          ),
          mode: MatchingMode.key,
        ),
      ),
      throwsA(isA<WorkflowIssue>()),
    );
  });
  test(
    'over-budget sequence does not manufacture positional matches or additions',
    () {
      final a = table('A', [
        'ID',
        'Value',
      ], List.generate(2000, (i) => ['ID_$i', 'old $i']));
      final b = table(
        'B',
        ['ID', 'Value'],
        [
          ['NEW', 'new'],
          ...List.generate(2000, (i) => ['ID_$i', 'new $i']),
        ],
      );
      final r = compare(plan(a, b));
      expect(r.matchedRecords, 0);
      expect(r.cells, isEmpty);
      expect(r.structural, isEmpty);
      expect(r.unresolvedRecords.expand((g) => g.recordsA).length, 2000);
      expect(r.unresolvedRecords.expand((g) => g.recordsB).length, 2001);
    },
  );
  test('missing columns are DIFFERENT even when blank', () {
    final r = compare(
      plan(
        table(
          'A',
          ['ID', 'Extra'],
          [
            ['1', ''],
          ],
        ),
        table(
          'B',
          ['ID'],
          [
            ['1'],
          ],
        ),
        mode: MatchingMode.positional,
      ),
    );
    expect(r.count(DecisionStatus.different), 1);
    expect(r.cells.last.decision.ruleId, 'schema/missing_column');
  });
  test('word highlight matches web, long strings do not claim false 100%', () {
    final d = WordDifference.between(
      'SUBMIT a none-page PDF',
      'SUBMIT a one-page PDF',
    );
    expect(d.a.where((t) => t.changed).map((t) => t.text), ['none']);
    expect(d.b.where((t) => t.changed).map((t) => t.text), ['one']);
    expect(d.similarity, 95);
    expect(WordDifference.between('a' * 1001, 'b' * 1001).similarity, isNull);
  });
  test('native worker preserves frozen binding and can be cancelled', () async {
    final p = plan(
      table(
        'A',
        ['ID'],
        [
          ['1'],
        ],
      ),
      table(
        'B',
        ['ID'],
        [
          ['1'],
        ],
      ),
    );
    final port = MobileComparisonPort();
    final r = await port.compare(p, Cancellation(), (_, _, _) {});
    expect(identical(r.plan, p), isTrue);
    expect(r.count(DecisionStatus.exact), 1);
    final cancel = Cancellation();
    final future = port.compare(p, cancel, (_, _, _) {});
    cancel.cancel();
    await expectLater(future, throwsA(isA<WorkCancelled>()));
  });
  test('real CSV -> automatic proposal -> native worker -> JSON/CSV', () async {
    final flow = createMobileWorkflow();
    addTearDown(flow.dispose);
    for (final side in SourceSide.values) {
      final info = MobileFileUploadService.processFileBytes(
        side: side,
        fileName: '${side.name}.csv',
        bytes: Uint8List.fromList(
          utf8.encode(
            side == SourceSide.a
                ? 'ID,Score\n001,8.5\n002,9'
                : 'ID,Score\n002,9\n001,"8,5"',
          ),
        ),
      );
      await flow.selectSource(
        side,
        info.format,
        info.privateRef,
        info.fileName,
      );
      await flow.importSource(side);
    }
    flow.applyProposal();
    expect(flow.startBlockers, isEmpty);
    await flow.runComparison();
    expect(flow.resultCurrent, isTrue);
    expect(flow.result!.count(DecisionStatus.equivalent), 1);
    final json = renderMobileReport(
      flow.result!,
      const ExportRequest(
        ExportKind.jsonReport,
        ExportSelection.fullComparison,
      ),
    );
    expect((jsonDecode(json.previewText)['cells'] as List).length, 4);
    final csv = renderMobileReport(
      flow.result!,
      const ExportRequest(ExportKind.csvDiff, ExportSelection.differencesOnly),
    );
    expect(csv.fileName, 'dytava-differences.csv');
    await flow.closeSession();
    expect(flow.result, isNull);
  });
  test('CSV preserves embedded newlines and JSON rejects nested cells', () {
    final info = MobileFileUploadService.processFileBytes(
      side: SourceSide.a,
      fileName: 'data.csv',
      bytes: Uint8List.fromList(utf8.encode('ID;Note\n001;"first\nsecond"')),
    );
    expect(info.rowCount, 1);
    expect(info.columnCount, 2);
    expect(
      () => MobileFileUploadService.processFileBytes(
        side: SourceSide.a,
        fileName: 'bad.json',
        bytes: Uint8List.fromList(utf8.encode('[{"a":{}}]')),
      ),
      throwsFormatException,
    );
  });
}
