import 'dart:convert';
import 'dart:isolate';

import '../domain/workflow.dart';

/// Portable local report preview; the view offers an explicit native Save action.
final class MobileExportPort implements ExportPort {
  @override
  bool supports(ExportKind kind) =>
      kind == ExportKind.csvDiff || kind == ExportKind.jsonReport;
  @override
  Future<PreparedExport> render(
    ComparisonResult result,
    ExportRequest request,
    Cancellation cancel,
  ) async {
    cancel.check();
    if (!supports(request.kind)) {
      throw const WorkflowIssue(
        'EXPORT_CAPABILITY_DISABLED',
        'Chọn CSV hoặc JSON.',
      );
    }
    final output = await Isolate.run(() => renderMobileReport(result, request));
    cancel.check();
    return output;
  }

  @override
  Future<void> verify(PreparedExport pending, Cancellation cancel) async {
    cancel.check();
    if (pending.previewText.isEmpty) {
      throw const WorkflowIssue('EXPORT_EMPTY', 'Báo cáo trống.');
    }
  }

  @override
  Future<ExportReceipt> publish(
    PreparedExport pending,
    String attemptId,
    Cancellation cancel,
  ) async {
    cancel.check();
    return ExportReceipt(
      attemptId,
      pending.previewText,
      previewOnly: true,
      fileName: pending.fileName,
    );
  }

  @override
  Future<void> discard(PreparedExport? pending) async {}
}

PreparedExport renderMobileReport(
  ComparisonResult result,
  ExportRequest request,
) {
  final cells = result.cells
      .where(
        (c) =>
            request.selection == ExportSelection.fullComparison ||
            ['different', 'unresolved'].contains(c.decision.status.name),
      )
      .toList();
  if (request.kind == ExportKind.csvDiff) {
    String quote(Object? value) {
      var s = value?.toString() ?? '';
      if (RegExp(r'^\s*[=+\-@]').hasMatch(s)) s = "'$s";
      return '"${s.replaceAll('"', '""')}"';
    }

    final rows = <List<Object?>>[
      [
        'kind',
        'status',
        'row_a',
        'row_b',
        'field_a',
        'field_b',
        'raw_a',
        'raw_b',
        'normalized_a',
        'normalized_b',
        'rule',
        'reason',
      ],
      for (final c in cells)
        [
          'CELL',
          c.decision.status.name,
          c.rowA,
          c.rowB,
          c.mapping.fieldA,
          c.mapping.fieldB,
          c.a.rawLexeme,
          c.b.rawLexeme,
          c.decision.left?.label,
          c.decision.right?.label,
          c.decision.ruleId,
          c.decision.explanation,
        ],
      for (final r in result.alignedRows.where(
        (r) => r.a == null || r.b == null || r.unresolved,
      ))
        [
          'ROW',
          r.unresolved
              ? 'UNRESOLVED'
              : r.a == null
              ? 'ADDED'
              : 'REMOVED',
          r.a?.id,
          r.b?.id,
          '',
          '',
          r.a == null
              ? ''
              : jsonEncode({
                  for (final e in r.a!.cells.entries) e.key: e.value.rawLexeme,
                }),
          r.b == null
              ? ''
              : jsonEncode({
                  for (final e in r.b!.cells.entries) e.key: e.value.rawLexeme,
                }),
          '',
          '',
          '',
          r.rationale,
        ],
      for (final s in result.structural.where(
        (s) => s.kind.startsWith('FIELD'),
      ))
        ['SCHEMA', s.kind, s.side.name, '', s.recordId],
    ];
    return PreparedExport(
      '\ufeff${rows.map((r) => r.map(quote).join(',')).join('\r\n')}',
      cells.length,
      fileName: 'dytava-differences.csv',
    );
  }
  return PreparedExport(
    const JsonEncoder.withIndent('  ').convert({
      'schema': 'dytava-mobile-web-parity/v1',
      'selection': request.selection.name,
      'result_id': result.id,
      'alignment_mode': result.plan.config.mode.name,
      'direction': result.plan.config.direction.name,
      'duration_ms': result.durationMs,
      'summary': {
        for (final s in ['exact', 'equivalent', 'different', 'unresolved'])
          s: result.cells.where((c) => c.decision.status.name == s).length,
      },
      'cells': [
        for (final c in cells)
          {
            'id': c.id,
            'row_a': c.rowA,
            'row_b': c.rowB,
            'field_a': c.mapping.fieldA,
            'field_b': c.mapping.fieldB,
            'raw_a': c.a.rawLexeme,
            'raw_b': c.b.rawLexeme,
            'normalized_a': c.decision.left?.label,
            'normalized_b': c.decision.right?.label,
            'status': c.decision.status.name,
            'rule_id': c.decision.ruleId,
            'reason': c.decision.explanation,
            'location_a': c.locationA,
            'location_b': c.locationB,
          },
      ],
      'structural': [
        for (final s in result.structural)
          {'kind': s.kind, 'side': s.side.name, 'record': s.recordId},
      ],
      'unresolved_records': [
        for (final r in result.unresolvedRecords)
          {'reason': r.reason, 'a': r.recordsA, 'b': r.recordsB},
      ],
      'alignment': [
        for (final r in result.alignedRows)
          {
            'row_a': r.a?.id,
            'row_b': r.b?.id,
            'line_a': r.a == null ? null : r.a!.ordinal + 1,
            'line_b': r.b == null ? null : r.b!.ordinal + 1,
            'reason': r.rationale,
            'unresolved': r.unresolved,
          },
      ],
    }),
    cells.length,
    fileName: 'dytava-report.json',
  );
}
