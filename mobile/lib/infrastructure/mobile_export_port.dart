import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../domain/workflow.dart';

/// Portable local report preview; the view offers an explicit native Save action.
final class MobileExportPort implements ExportPort {
  @override
  bool supports(ExportKind kind) =>
      kind == ExportKind.csvDiff ||
      kind == ExportKind.jsonReport ||
      kind == ExportKind.dytavaReportPdf;
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
        'Chọn CSV, JSON hoặc PDF.',
      );
    }
    final output = kIsWeb
        ? renderMobileReport(result, request)
        : await Isolate.run(() => renderMobileReport(result, request));
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
      fileBytes: pending.fileBytes,
    );
  }

  @override
  Future<void> discard(PreparedExport? pending) async {}
}

PreparedExport renderMobileReport(
  ComparisonResult result,
  ExportRequest request,
) {
  if (result.sheetResults.isNotEmpty && request.kind == ExportKind.csvDiff) {
    final parts = result.sheetResults
        .map((r) => renderMobileReport(r, request))
        .toList();
    final first = parts.first.previewText;
    final headerEnd = first.indexOf('\r\n');
    final header = headerEnd < 0 ? first : first.substring(0, headerEnd);
    final bodies = parts
        .map((p) {
          final i = p.previewText.indexOf('\r\n');
          return i < 0 ? '' : p.previewText.substring(i + 2);
        })
        .where((s) => s.isNotEmpty);
    return PreparedExport(
      [header, ...bodies].join('\r\n'),
      parts.fold(0, (n, p) => n + p.selectedCellCount),
      fileName: 'dytava-workbook-differences.csv',
    );
  }
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
        'sheet_a',
        'sheet_b',
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
          result.sheetPair?.nameA,
          result.sheetPair?.nameB,
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
          result.sheetPair?.nameA,
          result.sheetPair?.nameB,
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
        (s) => s.kind.startsWith('FIELD') || s.kind.startsWith('SHEET'),
      ))
        [
          result.sheetPair?.nameA,
          result.sheetPair?.nameB,
          'SCHEMA',
          s.kind,
          s.side.name,
          '',
          s.recordId,
        ],
    ];
    return PreparedExport(
      '\ufeff${rows.map((r) => r.map(quote).join(',')).join('\r\n')}',
      cells.length,
      fileName: 'dytava-differences.csv',
    );
  }
  if (request.kind == ExportKind.dytavaReportPdf) {
    return _renderPdfReport(result, request, cells);
  }
  return PreparedExport(
    const JsonEncoder.withIndent('  ').convert({
      'schema': 'dytava-mobile-web-parity/v1',
      'scope': result.sheetResults.isNotEmpty ? 'ALL_WORKSHEETS' : 'TABLE',
      'sheet_pair': result.sheetPair == null
          ? null
          : {
              'id': result.sheetPair!.id,
              'a': result.sheetPair!.nameA,
              'b': result.sheetPair!.nameB,
              'method': result.sheetPair!.method,
              'score': result.sheetPair!.score,
            },
      'warnings': result.warnings,
      if (result.sheetResults.isNotEmpty)
        'sheets': [
          for (final sheet in result.sheetResults)
            jsonDecode(
              renderMobileReport(
                sheet,
                ExportRequest(ExportKind.jsonReport, request.selection),
              ).previewText,
            ),
        ],
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
            'kind_a': c.a.kind.name,
            'kind_b': c.b.kind.name,
            if (c.a.imageDigest != null) 'image_sha256_a': c.a.imageDigest,
            if (c.b.imageDigest != null) 'image_sha256_b': c.b.imageDigest,
            if (c.a.imagePlacement != null)
              'image_placement_a': c.a.imagePlacement,
            if (c.b.imagePlacement != null)
              'image_placement_b': c.b.imagePlacement,
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

PreparedExport _renderPdfReport(
  ComparisonResult result,
  ExportRequest request,
  List<CellDifference> cells,
) {
  final exactCount = result.cells
      .where((c) => c.decision.status.name == 'exact')
      .length;
  final eqCount = result.cells
      .where((c) => c.decision.status.name == 'equivalent')
      .length;
  final diffCount = result.cells
      .where((c) => c.decision.status.name == 'different')
      .length;
  final unresCount = result.cells
      .where((c) => c.decision.status.name == 'unresolved')
      .length;

  final lines = <String>[
    'DYTAVA - EXCEL COMPARE REPORT (PDF)',
    '============================================================',
    'Report ID      : ${result.id}',
    'Scope          : ${request.selection.name}',
    'Alignment Mode : ${result.plan.config.mode.name}',
    'Direction      : ${result.plan.config.direction.name}',
    'Total Cells    : ${result.cells.length} (Selected: ${cells.length})',
    'Summary        : Exact=$exactCount | Equivalent=$eqCount | Different=$diffCount | Unresolved=$unresCount',
    '------------------------------------------------------------',
    'CELL DIFFERENCES & VERDICTS:',
  ];

  if (cells.isEmpty) {
    lines.add('  (No cell differences in selected scope)');
  } else {
    final maxEntries = cells.length > 400 ? 400 : cells.length;
    for (var i = 0; i < maxEntries; i++) {
      final c = cells[i];
      final sheetLabel = result.sheetPair != null
          ? '${result.sheetPair!.nameA}->${result.sheetPair!.nameB} '
          : '';
      final rawA = (c.a.rawLexeme ?? '').replaceAll(RegExp(r'[\r\n]+'), ' ');
      final rawB = (c.b.rawLexeme ?? '').replaceAll(RegExp(r'[\r\n]+'), ' ');
      lines.add(
        '${(i + 1).toString().padLeft(3, '0')}. [${c.decision.status.name.toUpperCase()}] '
        '$sheetLabel${c.mapping.fieldA} (Row ${c.rowA} -> ${c.rowB}): '
        '"$rawA"  -->  "$rawB"',
      );
    }
    if (cells.length > maxEntries) {
      lines.add('... and ${cells.length - maxEntries} additional cells.');
    }
  }

  if (result.structural.isNotEmpty) {
    lines.add('------------------------------------------------------------');
    lines.add('STRUCTURAL CHANGES (${result.structural.length}):');
    for (final s in result.structural.take(100)) {
      lines.add('  - ${s.kind} (${s.side.name.toUpperCase()}): ${s.recordId}');
    }
  }

  final previewText = lines.join('\n');
  final pdfBytes = _encodeMultiPagePdfDocument(lines);

  return PreparedExport(
    previewText,
    cells.length,
    fileName: 'dytava-report.pdf',
    fileBytes: pdfBytes,
  );
}

String _toAsciiPdfSafe(String input) {
  const Map<String, String> vnMap = {
    'à': 'a', 'á': 'a', 'ả': 'a', 'ã': 'a', 'ạ': 'a',
    'ă': 'a', 'ằ': 'a', 'ắ': 'a', 'ẳ': 'a', 'ẵ': 'a', 'ặ': 'a',
    'â': 'a', 'ầ': 'a', 'ấ': 'a', 'ẩ': 'a', 'ẫ': 'a', 'ậ': 'a',
    'è': 'e', 'é': 'e', 'ẻ': 'e', 'ẽ': 'e', 'ẹ': 'e',
    'ê': 'e', 'ề': 'e', 'ế': 'e', 'ể': 'e', 'ễ': 'e', 'ệ': 'e',
    'ì': 'i', 'í': 'i', 'ỉ': 'i', 'ĩ': 'i', 'ị': 'i',
    'ò': 'o', 'ó': 'o', 'ỏ': 'o', 'õ': 'o', 'ọ': 'o',
    'ô': 'o', 'ồ': 'o', 'ố': 'o', 'ổ': 'o', 'ỗ': 'o', 'ộ': 'o',
    'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ở': 'o', 'ỡ': 'o', 'ợ': 'o',
    'ù': 'u', 'ú': 'u', 'ủ': 'u', 'ũ': 'u', 'ụ': 'u',
    'ư': 'u', 'ừ': 'u', 'ứ': 'u', 'ử': 'u', 'ữ': 'u', 'ự': 'u',
    'ỳ': 'y', 'ý': 'y', 'ỷ': 'y', 'ỹ': 'y', 'ỵ': 'y',
    'đ': 'd',
    'À': 'A', 'Á': 'A', 'Ả': 'A', 'Ã': 'A', 'Ạ': 'A',
    'Ă': 'A', 'Ằ': 'A', 'Ắ': 'A', 'Ẳ': 'A', 'Ẵ': 'A', 'Ặ': 'A',
    'Â': 'A', 'Ầ': 'A', 'Ấ': 'A', 'Ẩ': 'A', 'Ẫ': 'A', 'Ậ': 'A',
    'È': 'E', 'É': 'E', 'Ẻ': 'E', 'Ẽ': 'E', 'Ẹ': 'E',
    'Ê': 'E', 'Ề': 'E', 'Ế': 'E', 'Ể': 'E', 'Ễ': 'E', 'Ệ': 'E',
    'Ì': 'I', 'Í': 'I', 'Ỉ': 'I', 'Ĩ': 'I', 'Ị': 'I',
    'Ò': 'O', 'Ó': 'O', 'Ỏ': 'O', 'Õ': 'O', 'Ọ': 'O',
    'Ô': 'O', 'Ồ': 'O', 'Ố': 'O', 'Ổ': 'O', 'Ỗ': 'O', 'Ộ': 'O',
    'Ơ': 'O', 'Ờ': 'O', 'Ớ': 'O', 'Ở': 'O', 'Ỡ': 'O', 'Ợ': 'O',
    'Ù': 'U', 'Ú': 'U', 'Ủ': 'U', 'Ũ': 'U', 'Ụ': 'U',
    'Ư': 'U', 'Ừ': 'U', 'Ứ': 'U', 'Ử': 'U', 'Ữ': 'U', 'Ự': 'U',
    'Ỳ': 'Y', 'Ý': 'Y', 'Ỷ': 'Y', 'Ỹ': 'Y', 'Ỵ': 'Y',
    'Đ': 'D',
  };
  final sb = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    final ch = input[i];
    final mapped = vnMap[ch];
    if (mapped != null) {
      sb.write(mapped);
    } else {
      final code = ch.codeUnitAt(0);
      if (code >= 32 && code <= 126) {
        if (ch == r'\' || ch == '(' || ch == ')') {
          sb.write(r'\');
        }
        sb.write(ch);
      } else {
        sb.write(' ');
      }
    }
  }
  return sb.toString();
}

/// Generates a standard PDF 1.4 binary document with multi-page layout.
Uint8List _encodeMultiPagePdfDocument(List<String> lines) {
  const int linesPerPage = 46;
  final pages = <List<String>>[];
  for (var i = 0; i < lines.length; i += linesPerPage) {
    final end = (i + linesPerPage < lines.length) ? i + linesPerPage : lines.length;
    pages.add(lines.sublist(i, end));
  }
  if (pages.isEmpty) {
    pages.add(const ['DYTAVA - EXCEL COMPARE REPORT']);
  }

  // Object IDs:
  // 1: Catalog
  // 2: Pages
  // 3: Font (Helvetica)
  // 4..(3 + 2*N): Page_i and Content_i
  final objects = <int, String>{};
  objects[1] = '<< /Type /Catalog /Pages 2 0 R >>';
  objects[3] = '<< /Type /Font /Subtype /Type1 /BaseFont /Courier >>';

  final pageRefs = <String>[];
  var nextObjId = 4;

  for (var pIdx = 0; pIdx < pages.length; pIdx++) {
    final pageObjId = nextObjId++;
    final contentObjId = nextObjId++;
    pageRefs.add('$pageObjId 0 R');

    final streamBuf = StringBuffer()
      ..writeln('BT')
      ..writeln('/F1 9.5 Tf')
      ..writeln('36 800 Td')
      ..writeln('15 TL');

    for (final rawLine in pages[pIdx]) {
      final trimmed = rawLine.length > 96 ? '${rawLine.substring(0, 93)}...' : rawLine;
      final safe = _toAsciiPdfSafe(trimmed);
      streamBuf.writeln('($safe) Tj T*');
    }
    streamBuf.write('ET');
    final streamContent = streamBuf.toString();
    final streamLen = utf8.encode(streamContent).length;

    objects[pageObjId] =
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] '
        '/Resources << /Font << /F1 3 0 R >> >> /Contents $contentObjId 0 R >>';
    objects[contentObjId] =
        '<< /Length $streamLen >>\nstream\n$streamContent\nendstream';
  }

  objects[2] =
      '<< /Type /Pages /Kids [${pageRefs.join(' ')}] /Count ${pages.length} >>';

  final totalObjects = nextObjId - 1;
  final out = StringBuffer();
  out.write('%PDF-1.4\n');

  final offsets = List<int>.filled(totalObjects + 1, 0);
  for (var id = 1; id <= totalObjects; id++) {
    offsets[id] = utf8.encode(out.toString()).length;
    out.write('$id 0 obj\n${objects[id]}\nendobj\n');
  }

  final xrefOffset = utf8.encode(out.toString()).length;
  out.write('xref\n0 ${totalObjects + 1}\n');
  out.write('0000000000 65535 f \n');
  for (var id = 1; id <= totalObjects; id++) {
    out.write('${offsets[id].toString().padLeft(10, '0')} 00000 n \n');
  }
  out.write(
    'trailer\n<< /Size ${totalObjects + 1} /Root 1 0 R >>\n'
    'startxref\n$xrefOffset\n%%EOF\n',
  );

  return Uint8List.fromList(utf8.encode(out.toString()));
}
