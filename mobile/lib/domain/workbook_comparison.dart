import 'package:excelcompare_core/excelcompare_core.dart';

import 'workflow.dart';

List<InputSnapshot> workbookTables(InputSnapshot source) =>
    source.workbookSheets.isEmpty ? [source] : source.workbookSheets;
SheetDescriptor describeSnapshot(InputSnapshot table) {
  final types = <String>[];
  for (final f in table.fields) {
    final counts = <String, int>{};
    for (final row in table.records.take(64)) {
      final cell = row.cells[f.id], v = cell?.rawLexeme?.trim() ?? '';
      if (v.isEmpty) continue;
      final type = cell?.kind == CellKind.image
          ? 'image'
          : cell?.kind == CellKind.unsupported
          ? 'unsupported'
          : RegExp(r'^\d{4}-\d\d-\d\d').hasMatch(v)
          ? 'date'
          : RegExp(r'^(true|false)$', caseSensitive: false).hasMatch(v)
          ? 'boolean'
          : RegExp(r'^0\d+$').hasMatch(v)
          ? 'identifier'
          : RegExp(r'^[+-]?\d+(?:[.,]\d+)?%?$').hasMatch(v)
          ? 'number'
          : 'text';
      counts[type] = (counts[type] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) {
        final n = b.value.compareTo(a.value);
        return n == 0 ? a.key.compareTo(b.key) : n;
      });
    types.add(entries.firstOrNull?.key ?? 'empty');
  }
  return SheetDescriptor(
    table.sheetName ?? '',
    table.fields.map((f) => f.label),
    types,
  );
}

SheetMappingPlan mapWorkbookSnapshots(
  InputSnapshot a,
  InputSnapshot b, {
  List<(String?, String?)> overrides = const [],
}) => mapSheets(
  workbookTables(a).map(describeSnapshot).toList(),
  workbookTables(b).map(describeSnapshot).toList(),
  overrides: overrides,
);
