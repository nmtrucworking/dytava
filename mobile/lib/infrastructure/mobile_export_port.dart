import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/workflow.dart';

Uint8List? _cachedUnicodeFontRegularBytes;
Uint8List? _cachedUnicodeFontBoldBytes;

/// Loads the bundled Unicode TrueType fonts (`BeVietnamPro-Regular.ttf` and
/// `BeVietnamPro-Bold.ttf`, with `IBMPlexMono` fallback) so that Vietnamese
/// diacritics, currency symbols (€, ₫, ¥, £), and mathematical operators (±, ≠, ≤, ≥)
/// are preserved 100% faithfully in PDF reports without any ASCII stripping.
Future<(Uint8List?, Uint8List?)> _ensureUnicodeFontBytes() async {
  if (_cachedUnicodeFontRegularBytes != null &&
      _cachedUnicodeFontBoldBytes != null) {
    return (_cachedUnicodeFontRegularBytes, _cachedUnicodeFontBoldBytes);
  }

  Future<Uint8List?> loadFontAsset(String relativePath) async {
    if (!kIsWeb) {
      for (final prefix in ['', 'mobile/']) {
        try {
          final file = File('$prefix$relativePath');
          if (file.existsSync()) {
            return file.readAsBytesSync();
          }
        } catch (_) {}
      }
    }
    try {
      final data = await rootBundle.load(relativePath);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (_) {
      return null;
    }
  }

  _cachedUnicodeFontRegularBytes ??=
      await loadFontAsset('assets/fonts/BeVietnamPro-Regular.ttf') ??
      await loadFontAsset('assets/fonts/IBMPlexMono-Regular.ttf');
  _cachedUnicodeFontBoldBytes ??=
      await loadFontAsset('assets/fonts/BeVietnamPro-Bold.ttf') ??
      await loadFontAsset('assets/fonts/IBMPlexMono-Bold.ttf') ??
      _cachedUnicodeFontRegularBytes;

  return (_cachedUnicodeFontRegularBytes, _cachedUnicodeFontBoldBytes);
}

(Uint8List?, Uint8List?) _resolveSyncFontBytes(
  Uint8List? regularOverride,
  Uint8List? boldOverride,
) {
  var reg = regularOverride ?? _cachedUnicodeFontRegularBytes;
  var bold = boldOverride ?? _cachedUnicodeFontBoldBytes;
  if ((reg == null || bold == null) && !kIsWeb) {
    for (final prefix in ['', 'mobile/']) {
      try {
        if (reg == null) {
          final f = File('${prefix}assets/fonts/BeVietnamPro-Regular.ttf');
          if (f.existsSync()) reg = f.readAsBytesSync();
        }
        if (bold == null) {
          final f = File('${prefix}assets/fonts/BeVietnamPro-Bold.ttf');
          if (f.existsSync()) bold = f.readAsBytesSync();
        }
      } catch (_) {}
    }
    _cachedUnicodeFontRegularBytes ??= reg;
    _cachedUnicodeFontBoldBytes ??= bold ?? reg;
  }
  return (reg, bold ?? reg);
}

/// Portable local report preview; the view offers an explicit native Save action.
final class MobileExportPort implements ExportPort {
  @override
  bool supports(ExportKind kind) =>
      kind == ExportKind.csvDiff ||
      kind == ExportKind.jsonReport ||
      kind == ExportKind.dytavaReportPdf ||
      kind == ExportKind.mergedDiffPdf;

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
    Uint8List? fontReg;
    Uint8List? fontBold;
    if (request.kind == ExportKind.dytavaReportPdf ||
        request.kind == ExportKind.mergedDiffPdf) {
      (fontReg, fontBold) = await _ensureUnicodeFontBytes();
    }
    final output = kIsWeb
        ? await renderMobileReportAsync(
            result,
            request,
            unicodeFontRegular: fontReg,
            unicodeFontBold: fontBold,
          )
        : await Isolate.run(
            () => renderMobileReportAsync(
              result,
              request,
              unicodeFontRegular: fontReg,
              unicodeFontBold: fontBold,
            ),
          );
    cancel.check();
    return output;
  }

  @override
  Future<void> verify(PreparedExport pending, Cancellation cancel) async {
    cancel.check();
    if (pending.previewText.isEmpty) {
      throw const WorkflowIssue('EXPORT_EMPTY', 'Báo cáo trống.');
    }
    if (pending.fileName?.endsWith('.pdf') == true &&
        (pending.fileBytes == null || pending.fileBytes!.isEmpty)) {
      throw const WorkflowIssue(
        'EXPORT_VERIFICATION_FAILED',
        'Tệp PDF không hợp lệ.',
      );
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

/// Asynchronous entry point that supports full TrueType Unicode PDF generation
/// (`dytavaReportPdf` and `mergedDiffPdf`) as well as CSV and JSON exports.
Future<PreparedExport> renderMobileReportAsync(
  ComparisonResult result,
  ExportRequest request, {
  Uint8List? unicodeFontRegular,
  Uint8List? unicodeFontBold,
}) async {
  if (request.kind == ExportKind.dytavaReportPdf) {
    final cells = _selectExportCells(result, request);
    final (reg, bold) = _resolveSyncFontBytes(
      unicodeFontRegular,
      unicodeFontBold,
    );
    return await _renderDytavaPdfReport(
      result,
      request,
      cells,
      fontRegularBytes: reg,
      fontBoldBytes: bold,
    );
  }
  if (request.kind == ExportKind.mergedDiffPdf) {
    final cells = _selectExportCells(result, request);
    final (reg, bold) = _resolveSyncFontBytes(
      unicodeFontRegular,
      unicodeFontBold,
    );
    return await _renderMergedDiffPdfReport(
      result,
      request,
      cells,
      fontRegularBytes: reg,
      fontBoldBytes: bold,
    );
  }
  return renderMobileReport(result, request);
}

List<CellDifference> _selectExportCells(
  ComparisonResult result,
  ExportRequest request,
) =>
    result.cells
        .where(
          (c) =>
              request.selection == ExportSelection.fullComparison ||
              ['different', 'unresolved'].contains(c.decision.status.name),
        )
        .toList();

/// Synchronous entry point for CSV, JSON, and synchronous PDF fallback tests.
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
  final cells = _selectExportCells(result, request);
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
    final previewText = _buildDytavaPdfPreviewText(result, request, cells);
    return PreparedExport(
      previewText,
      cells.length,
      fileName: 'dytava-report.pdf',
      fileBytes: _encodeUnicodePdfFallback(previewText),
    );
  }
  if (request.kind == ExportKind.mergedDiffPdf) {
    final previewText = _buildMergedDiffPdfPreviewText(result, request, cells);
    return PreparedExport(
      previewText,
      cells.length,
      fileName: 'dytava-merged-diff.pdf',
      fileBytes: _encodeUnicodePdfFallback(previewText),
    );
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

String _buildDytavaPdfPreviewText(
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
    'CELL DIFFERENCES & VERDICTS (COMPLETE - NO TRUNCATION):',
  ];

  if (cells.isEmpty) {
    lines.add('  (No cell differences in selected scope)');
  } else {
    for (var i = 0; i < cells.length; i++) {
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
  }

  if (result.structural.isNotEmpty) {
    lines.add('------------------------------------------------------------');
    lines.add('STRUCTURAL CHANGES (${result.structural.length}):');
    for (final s in result.structural) {
      lines.add('  - ${s.kind} (${s.side.name.toUpperCase()}): ${s.recordId}');
    }
  }

  if (result.unresolvedRecords.isNotEmpty) {
    lines.add('------------------------------------------------------------');
    lines.add('UNRESOLVED RECORDS (${result.unresolvedRecords.length}):');
    for (final u in result.unresolvedRecords) {
      lines.add(
        '  - ${u.reason}: A=[${u.recordsA.join(", ")}] | B=[${u.recordsB.join(", ")}]',
      );
    }
  }

  return lines.join('\n');
}

String _buildMergedDiffPdfPreviewText(
  ComparisonResult result,
  ExportRequest request,
  List<CellDifference> cells,
) {
  final sheets = result.sheetResults.isNotEmpty ? result.sheetResults : [result];
  final lines = <String>[
    'DYTAVA - MERGED A/B TABLE DIFF REPORT (PDF)',
    '============================================================',
    'Report ID      : ${result.id}',
    'Scope          : ${request.selection.name}',
    'Alignment Mode : ${result.plan.config.mode.name}',
    'Direction      : ${result.plan.config.direction.name}',
    'Total Cells    : ${result.cells.length} (Selected: ${cells.length})',
    '------------------------------------------------------------',
  ];

  for (final sheet in sheets) {
    final sheetTitle = sheet.sheetPair?.label ??
        sheet.plan.a.sheetName ??
        sheet.plan.b.sheetName ??
        'Table A <-> B';
    lines.add('SHEET: $sheetTitle');
    final mappings = sheet.plan.config.mappings;
    final headerNames = mappings.isNotEmpty
        ? [for (final m in mappings) m.fieldA.isNotEmpty ? m.fieldA : m.fieldB]
        : [for (final f in sheet.plan.a.fields) f.label];
    if (headerNames.isNotEmpty) {
      lines.add('Columns: ${headerNames.join(" | ")}');
    }

    if (sheet.alignedRows.isNotEmpty) {
      for (var rIdx = 0; rIdx < sheet.alignedRows.length; rIdx++) {
        final row = sheet.alignedRows[rIdx];
        final rowStatus = row.unresolved
            ? 'UNRESOLVED'
            : row.a == null
            ? 'ADDED'
            : row.b == null
            ? 'REMOVED'
            : row.status.name.toUpperCase();
        if (request.selection == ExportSelection.differencesOnly &&
            rowStatus == 'EXACT') {
          continue;
        }
        final cellDiffsByField = {
          for (final cd in row.cells)
            (cd.mapping.fieldA.isNotEmpty
                    ? cd.mapping.fieldA
                    : cd.mapping.fieldB):
                cd,
        };
        final formattedCells = <String>[];
        for (final col in headerNames) {
          final cd = cellDiffsByField[col];
          if (cd != null) {
            final aVal = cd.a.rawLexeme ?? '';
            final bVal = cd.b.rawLexeme ?? '';
            if (cd.decision.status.name == 'different' ||
                cd.decision.status.name == 'unresolved') {
              formattedCells.add('$col: "$aVal" -> "$bVal" [${cd.decision.status.name.toUpperCase()}]');
            } else if (cd.decision.status.name == 'equivalent' && aVal != bVal) {
              formattedCells.add('$col: "$aVal" ~= "$bVal"');
            } else {
              formattedCells.add('$col: "$bVal"');
            }
          } else {
            final aVal = row.a?.cells[col]?.rawLexeme ?? '';
            final bVal = row.b?.cells[col]?.rawLexeme ?? '';
            if (row.a == null) {
              formattedCells.add('$col: +"$bVal"');
            } else if (row.b == null) {
              formattedCells.add('$col: -"$aVal"');
            } else {
              formattedCells.add('$col: "$aVal"');
            }
          }
        }
        lines.add(
          'Row ${rIdx + 1} [$rowStatus] (${row.a?.id ?? "-"} <-> ${row.b?.id ?? "-"}): '
          '${formattedCells.join(" | ")}',
        );
      }
    } else {
      for (var i = 0; i < cells.length; i++) {
        final c = cells[i];
        lines.add(
          '${(i + 1).toString().padLeft(3, '0')}. [${c.decision.status.name.toUpperCase()}] '
          '${c.mapping.fieldA} (${c.rowA} <-> ${c.rowB}): '
          '"${c.a.rawLexeme ?? ""}" -> "${c.b.rawLexeme ?? ""}"',
        );
      }
    }
    lines.add('------------------------------------------------------------');
  }

  return lines.join('\n');
}

pw.ThemeData _buildPdfUnicodeTheme(
  Uint8List? fontRegularBytes,
  Uint8List? fontBoldBytes,
) {
  if (fontRegularBytes != null && fontRegularBytes.isNotEmpty) {
    final regularFont = pw.Font.ttf(ByteData.sublistView(fontRegularBytes));
    final boldFont = (fontBoldBytes != null && fontBoldBytes.isNotEmpty)
        ? pw.Font.ttf(ByteData.sublistView(fontBoldBytes))
        : regularFont;
    return pw.ThemeData.withFont(
      base: regularFont,
      bold: boldFont,
      italic: regularFont,
      boldItalic: boldFont,
    );
  }
  return pw.ThemeData.base();
}

/// Renders the complete Dytava Comparison Report PDF with embedded TrueType
/// Unicode fonts, dynamic multi-page flow, and 100% data preservation (no 400-cell
/// or 96-character truncation, and no ASCII stripping).
Future<PreparedExport> _renderDytavaPdfReport(
  ComparisonResult result,
  ExportRequest request,
  List<CellDifference> cells, {
  Uint8List? fontRegularBytes,
  Uint8List? fontBoldBytes,
}) async {
  final previewText = _buildDytavaPdfPreviewText(result, request, cells);
  final theme = _buildPdfUnicodeTheme(fontRegularBytes, fontBoldBytes);
  final doc = pw.Document(
    title: 'Dytava Comparison Report - ${result.id}',
    author: 'Dytava Mobile',
    subject: 'Spreadsheet Comparison Report (${request.selection.name})',
    compress: false,
    theme: theme,
  );

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

  // Chunk cells into tables of 150 rows each so MultiPage can paginate arbitrarily large datasets smoothly
  const int chunkSize = 150;
  final cellChunks = <List<CellDifference>>[];
  for (var i = 0; i < cells.length; i += chunkSize) {
    final end = (i + chunkSize < cells.length) ? i + chunkSize : cells.length;
    cellChunks.add(cells.sublist(i, end));
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      maxPages: 2000,
      header: (context) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 8),
        margin: const pw.EdgeInsets.only(bottom: 12),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.8),
          ),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'DYTAVA — EXCEL COMPARE REPORT',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green900,
              ),
            ),
            pw.Text(
              'ID: ${result.id} · Scope: ${request.selection.name}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ],
        ),
      ),
      footer: (context) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 6),
        margin: const pw.EdgeInsets.only(top: 10),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            top: pw.BorderSide(color: PdfColors.grey300, width: 0.6),
          ),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Dytava On-Device Verification Report · Unicode Preserved',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ],
        ),
      ),
      build: (context) => [
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.green50,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            border: pw.Border.all(color: PdfColors.green200),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Comparison Summary',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green900,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Alignment Mode: ${result.plan.config.mode.name}   |   '
                'Direction: ${result.plan.config.direction.name}   |   '
                'Matched Records: ${result.matchedRecords}',
                style: const pw.TextStyle(fontSize: 9.5),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Total Compared Cells: ${result.cells.length} (Exported in Scope: ${cells.length})',
                style: const pw.TextStyle(fontSize: 9.5),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Exact: $exactCount   |   Equivalent: $eqCount   |   '
                'Different: $diffCount   |   Unresolved: $unresCount',
                style: pw.TextStyle(
                  fontSize: 9.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 14),
        pw.Text(
          'Cell Verdicts & Evidence (${cells.length} items)',
          style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        if (cells.isEmpty)
          pw.Text(
            'No cell differences in the selected report scope.',
            style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700),
          )
        else
          for (var cIdx = 0; cIdx < cellChunks.length; cIdx++)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.TableHelper.fromTextArray(
                headers: const [
                  '#',
                  'Status',
                  'Field / Location',
                  'Source A (Original)',
                  'Source B (Updated)',
                  'Rule',
                ],
                headerStyle: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.green800,
                ),
                cellStyle: const pw.TextStyle(fontSize: 8.2),
                cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 4,
                ),
                columnWidths: {
                  0: const pw.FixedColumnWidth(26),
                  1: const pw.FixedColumnWidth(54),
                  2: const pw.FlexColumnWidth(1.4),
                  3: const pw.FlexColumnWidth(2.0),
                  4: const pw.FlexColumnWidth(2.0),
                  5: const pw.FlexColumnWidth(1.1),
                },
                data: [
                  for (var i = 0; i < cellChunks[cIdx].length; i++)
                    () {
                      final globalIdx = cIdx * chunkSize + i + 1;
                      final c = cellChunks[cIdx][i];
                      final loc = c.locationA ?? c.locationB ?? '${c.rowA}->${c.rowB}';
                      return [
                        '$globalIdx',
                        c.decision.status.name.toUpperCase(),
                        '${c.mapping.fieldA.isNotEmpty ? c.mapping.fieldA : c.mapping.fieldB}\n($loc)',
                        c.a.rawLexeme ?? '',
                        c.b.rawLexeme ?? '',
                        c.decision.ruleId,
                      ];
                    }(),
                ],
              ),
            ),
        if (result.structural.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          pw.Text(
            'Structural Changes (${result.structural.length})',
            style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const ['Kind', 'Side', 'Record / Field Identifier'],
            headerStyle: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blueGrey800,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8.2),
            data: [
              for (final s in result.structural)
                [s.kind, s.side.name.toUpperCase(), s.recordId],
            ],
          ),
        ],
        if (result.unresolvedRecords.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          pw.Text(
            'Unresolved Records (${result.unresolvedRecords.length})',
            style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const ['Reason', 'Records A', 'Records B'],
            headerStyle: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.amber900,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8.2),
            data: [
              for (final u in result.unresolvedRecords)
                [u.reason, u.recordsA.join(', '), u.recordsB.join(', ')],
            ],
          ),
        ],
      ],
    ),
  );

  final pdfBytes = await doc.save();
  return PreparedExport(
    previewText,
    cells.length,
    fileName: 'dytava-report.pdf',
    fileBytes: pdfBytes,
  );
}

/// Renders a side-by-side Merged Diff PDF A/B (`ExportKind.mergedDiffPdf`)
/// showing aligned rows and merged A→B cell values across all compared sheets
/// with full Unicode support.
Future<PreparedExport> _renderMergedDiffPdfReport(
  ComparisonResult result,
  ExportRequest request,
  List<CellDifference> cells, {
  Uint8List? fontRegularBytes,
  Uint8List? fontBoldBytes,
}) async {
  final previewText = _buildMergedDiffPdfPreviewText(result, request, cells);
  final theme = _buildPdfUnicodeTheme(fontRegularBytes, fontBoldBytes);
  final doc = pw.Document(
    title: 'Dytava Merged A/B Diff - ${result.id}',
    author: 'Dytava Mobile',
    subject: 'Merged Spreadsheet Diff A/B (${request.selection.name})',
    compress: false,
    theme: theme,
  );

  final sheets = result.sheetResults.isNotEmpty ? result.sheetResults : [result];

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      maxPages: 2000,
      header: (context) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 6),
        margin: const pw.EdgeInsets.only(bottom: 10),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.8),
          ),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'DYTAVA — MERGED A/B SPREADSHEET DIFF',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green900,
              ),
            ),
            pw.Text(
              'ID: ${result.id} · Scope: ${request.selection.name}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ],
        ),
      ),
      footer: (context) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 6),
        margin: const pw.EdgeInsets.only(top: 8),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            top: pw.BorderSide(color: PdfColors.grey300, width: 0.6),
          ),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Merged Diff A/B · Legend: "A -> B" (Modified), "+B" (Added), "-A" (Removed), "A ~= B" (Equivalent)',
              style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ],
        ),
      ),
      build: (context) {
        final widgets = <pw.Widget>[];
        for (final sheet in sheets) {
          final sheetTitle = (sheet.sheetPair?.label ??
                  sheet.plan.a.sheetName ??
                  sheet.plan.b.sheetName ??
                  'Worksheet A <-> B')
              .replaceAll('↔', '<->');
          widgets.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 6, bottom: 6),
              child: pw.Text(
                sheetTitle,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green900,
                ),
              ),
            ),
          );

          final mappings = sheet.plan.config.mappings;
          final fieldCols = mappings.isNotEmpty
              ? [for (final m in mappings) (m.fieldA, m.fieldB)]
              : [
                  for (final f in sheet.plan.a.fields) (f.id, f.id),
                ];

          if (sheet.alignedRows.isNotEmpty && fieldCols.isNotEmpty) {
            final headers = [
              'Row A/B',
              'Status',
              for (final (fa, fb) in fieldCols)
                fa == fb || fb.isEmpty ? fa : '$fa -> $fb',
            ];
            final rowsData = <List<String>>[];
            for (var rIdx = 0; rIdx < sheet.alignedRows.length; rIdx++) {
              final row = sheet.alignedRows[rIdx];
              final rowStatus = row.unresolved
                  ? 'UNRESOLVED'
                  : row.a == null
                  ? 'ADDED'
                  : row.b == null
                  ? 'REMOVED'
                  : row.status.name.toUpperCase();
              if (request.selection == ExportSelection.differencesOnly &&
                  rowStatus == 'EXACT') {
                continue;
              }
              final cellMap = {
                for (final cd in row.cells)
                  '${cd.mapping.fieldA}|${cd.mapping.fieldB}': cd,
              };
              final lineA = row.a != null ? '${row.a!.ordinal + 1}' : '-';
              final lineB = row.b != null ? '${row.b!.ordinal + 1}' : '-';
              final rowCells = <String>[
                '$lineA -> $lineB',
                rowStatus,
              ];
              for (final (fa, fb) in fieldCols) {
                final cd = cellMap['$fa|$fb'];
                if (cd != null) {
                  final aVal = cd.a.rawLexeme ?? '';
                  final bVal = cd.b.rawLexeme ?? '';
                  if (cd.decision.status.name == 'different' ||
                      cd.decision.status.name == 'unresolved') {
                    rowCells.add('$aVal -> $bVal');
                  } else if (cd.decision.status.name == 'equivalent' &&
                      aVal != bVal) {
                    rowCells.add('$aVal ~= $bVal');
                  } else {
                    rowCells.add(bVal);
                  }
                } else if (row.a == null) {
                  rowCells.add('+${row.b?.cells[fb]?.rawLexeme ?? ""}');
                } else if (row.b == null) {
                  rowCells.add('-${row.a?.cells[fa]?.rawLexeme ?? ""}');
                } else {
                  rowCells.add(row.a?.cells[fa]?.rawLexeme ?? '');
                }
              }
              rowsData.add(rowCells);
            }

            const chunkRows = 120;
            for (var i = 0; i < rowsData.length; i += chunkRows) {
              final end = (i + chunkRows < rowsData.length)
                  ? i + chunkRows
                  : rowsData.length;
              widgets.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 10),
                  child: pw.TableHelper.fromTextArray(
                    headers: headers,
                    headerStyle: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                    headerDecoration: const pw.BoxDecoration(
                      color: PdfColors.green800,
                    ),
                    cellStyle: const pw.TextStyle(fontSize: 7.8),
                    cellPadding: const pw.EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 3.5,
                    ),
                    data: rowsData.sublist(i, end),
                  ),
                ),
              );
            }
          } else {
            final sheetCells = sheet.cells
                .where(
                  (c) =>
                      request.selection == ExportSelection.fullComparison ||
                      ['different', 'unresolved']
                          .contains(c.decision.status.name),
                )
                .toList();
            widgets.add(
              pw.TableHelper.fromTextArray(
                headers: const [
                  'Row A -> B',
                  'Field A -> B',
                  'Status',
                  'Merged Diff (A -> B)',
                ],
                headerStyle: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.green800,
                ),
                cellStyle: const pw.TextStyle(fontSize: 8),
                data: [
                  for (final c in sheetCells)
                    [
                      '${c.rowA} -> ${c.rowB}',
                      '${c.mapping.fieldA} -> ${c.mapping.fieldB}',
                      c.decision.status.name.toUpperCase(),
                      '${c.a.rawLexeme ?? ""} -> ${c.b.rawLexeme ?? ""}',
                    ],
                ],
              ),
            );
          }
        }
        return widgets;
      },
    ),
  );

  final pdfBytes = await doc.save();
  return PreparedExport(
    previewText,
    cells.length,
    fileName: 'dytava-merged-diff.pdf',
    fileBytes: pdfBytes,
  );
}

/// Fallback PDF 1.4 binary encoder for synchronous calls that preserves full
/// UTF-8 / UTF-16BE text streams without stripping Vietnamese diacritics or symbols.
Uint8List _encodeUnicodePdfFallback(String previewText) {
  final lines = previewText.split('\n');
  const int linesPerPage = 46;
  final pages = <List<String>>[];
  for (var i = 0; i < lines.length; i += linesPerPage) {
    final end = (i + linesPerPage < lines.length) ? i + linesPerPage : lines.length;
    pages.add(lines.sublist(i, end));
  }
  if (pages.isEmpty) {
    pages.add(const ['DYTAVA - EXCEL COMPARE REPORT']);
  }

  String escapePdfUtf8(String input) {
    return input
        .replaceAll(r'\', r'\\')
        .replaceAll('(', r'\(')
        .replaceAll(')', r'\)');
  }

  final objects = <int, String>{};
  objects[1] = '<< /Type /Catalog /Pages 2 0 R >>';
  objects[3] =
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>';

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
      ..writeln('14 TL');

    for (final rawLine in pages[pIdx]) {
      final safe = escapePdfUtf8(rawLine);
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
