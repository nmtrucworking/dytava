import 'package:dytava/domain/workflow.dart';
import 'package:dytava/infrastructure/demo/demo_workflow_ports.dart';
import 'package:excelcompare_core/excelcompare_core.dart';
import 'package:flutter_test/flutter_test.dart' hide ComparisonResult;

InputSnapshot table(String side, List<List<String?>> data) => InputSnapshot(
  id: side,
  binding: ImportBinding(side, 1, 1, 1),
  fullValidation: true,
  ocrReviewed: false,
  fields: const [TableField('id', 'id'), TableField('amount', 'amount')],
  records: [
    for (var i = 0; i < data.length; i++)
      TableRecord('$side-$i', i, {
        'id': data[i][0] == null
            ? const SourceCell(CellKind.missing)
            : SourceCell(CellKind.text, rawLexeme: data[i][0]),
        'amount': SourceCell(CellKind.text, rawLexeme: data[i][1]),
      }, {}),
  ],
);
Future<ComparisonResult> compare(
  InputSnapshot a,
  InputSnapshot b, {
  MatchingMode mode = MatchingMode.key,
  List<String> keys = const ['id'],
  List<FieldMapping>? mappings,
}) => DemoComparisonPort().compare(
  FrozenPlan(
    'test-plan',
    1,
    a,
    b,
    ComparisonConfiguration(
      mappings:
          mappings ??
          const [FieldMapping('id', 'id'), FieldMapping('amount', 'amount')],
      mode: mode,
      keys: keys,
      rules: const {
        'id': FieldRule(type: SemanticType.identifier),
        'amount': FieldRule(type: SemanticType.identifier),
      },
    ),
  ),
  Cancellation(),
  (_, _, _) {},
);
void main() {
  test('KEY reordering does not create false diffs', () async {
    final r = await compare(
      table('a', [
        ['001', '8'],
        ['002', '9'],
      ]),
      table('b', [
        ['002', '9'],
        ['001', '8'],
      ]),
    );
    expect(r.matchedRecords, 2);
    expect(r.count(DecisionStatus.exact), 4);
    expect(r.structural, isEmpty);
    expect(r.cells.first.rowA, 'a-0');
    expect(r.cells.first.rowB, 'b-1');
  });
  test(
    'duplicate group owns every member on both sides, never first-row pairs',
    () async {
      final r = await compare(
        table('a', [
          ['001', '8'],
          ['001', '9'],
        ]),
        table('b', [
          ['001', '8'],
        ]),
      );
      expect(r.matchedRecords, 0);
      expect(r.cells, isEmpty);
      expect(r.structural, isEmpty);
      expect(r.unresolvedRecords.single.reason, 'KEY_DUPLICATE');
      expect(r.unresolvedRecords.single.recordsA.length, 2);
      expect(r.unresolvedRecords.single.recordsB.length, 1);
      expect(r.exactRate, isNull);
      expect(r.agreementRate, isNull);
    },
  );
  test('invalid key prevents false absence proof on opposite side', () async {
    final r = await compare(
      table('a', [
        ['001', '8'],
        [null, '9'],
      ]),
      table('b', [
        ['001', '8'],
        ['002', '9'],
      ]),
    );
    expect(r.matchedRecords, 1);
    expect(r.structural, isEmpty);
    expect(
      r.unresolvedRecords.map((g) => g.reason),
      containsAll(['KEY_INVALID', 'ABSENCE_NOT_PROVEN_INVALID_KEYS']),
    );
    expect(r.unresolvedRecords.expand((g) => g.recordsA), ['a-1']);
    expect(r.unresolvedRecords.expand((g) => g.recordsB), ['b-1']);
  });
  test(
    'tuple framing does not collide when values contain separators',
    () async {
      final r = await compare(
        table('a', [
          ['a|b', 'c'],
        ]),
        table('b', [
          ['a', 'b|c'],
        ]),
        keys: ['id', 'amount'],
      );
      expect(r.matchedRecords, 0);
      expect(r.structural.length, 2);
      expect(r.cells, isEmpty);
    },
  );
  test('POSITIONAL pairs by ordinal and does not infer reordering', () async {
    final r = await compare(
      table('a', [
        ['001', '8'],
        ['002', '9'],
      ]),
      table('b', [
        ['002', '9'],
        ['001', '8'],
        ['003', '1'],
      ]),
      mode: MatchingMode.positional,
    );
    expect(r.matchedRecords, 2);
    expect(r.count(DecisionStatus.different), 4);
    expect(r.structural.single.kind, 'ROW_ADDED');
  });
  test(
    'unmapped fields are structural events and never cell verdicts',
    () async {
      final r = await compare(
        table('a', [
          ['001', '8'],
        ]),
        table('b', [
          ['001', '9'],
        ]),
        mappings: const [FieldMapping('id', 'id')],
      );
      expect(r.cells.length, 1);
      expect(
        r.structural.map((s) => s.kind),
        containsAll(['FIELD_ADDED', 'FIELD_REMOVED']),
      );
    },
  );
}
