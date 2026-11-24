import 'dart:convert';
import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:xml/xml.dart';

import '../domain/workflow.dart';

import 'package:excelcompare_core/excelcompare_core.dart';

import 'xlsx_cell_content.dart';
import 'demo/demo_workflow_ports.dart';

final class UploadedFileInfo {
  const UploadedFileInfo({
    required this.fileName,
    required this.format,
    required this.privateRef,
    required this.rowCount,
    required this.columnCount,
    this.sha256Digest,
    this.sheets = const [],
    this.sheetName,
  });
  final String fileName, privateRef;
  final String? sha256Digest;
  final SourceFormat format;
  final int rowCount, columnCount;
  final List<String> sheets;
  final String? sheetName;
}

final class _ParsedTable {
  const _ParsedTable(
    this.headers,
    this.rows,
    this.headerRow, {
    this.sourceRows = const [],
    this.specialCells = const {},
    this.warnings = const [],
  });
  final List<String> headers;
  final List<List<String>> rows;
  final int headerRow;
  final List<int> sourceRows;
  final Map<String, SourceCell> specialCells;
  final List<String> warnings;
}

final class _ParsedFile {
  const _ParsedFile(this.name, this.format, this.tables, {this.sha256Digest});
  final String name;
  final SourceFormat format;
  final Map<String, _ParsedTable> tables;
  final String? sha256Digest;
}

abstract final class MobileFileUploadService {
  static const maxFileBytes = 500 * 1024 * 1024,
      maxRows = 1500000,
      maxColumns = 500,
      maxCells = 25000000;
  static final _files = <String, _ParsedFile>{};
  static final _selected = <String, String>{};
  static Future<UploadedFileInfo?> pickAndProcessFile(SourceSide side) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'tsv', 'txt', 'json', 'xlsx'],
    );
    if (files.isEmpty) return null;
    final file = files.first;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > maxFileBytes) {
      throw const FormatException('Tệp phải có dữ liệu và không vượt 500 MB.');
    }
    final name = file.name;
    final parsed = await _parseInBackground(name, bytes);
    return _register(side, parsed);
  }

  static Future<_ParsedFile> _parseInBackground(
    String name,
    Uint8List bytes,
  ) async {
    if (kIsWeb) {
      await Future<void>.delayed(Duration.zero);
      try {
        return _parse(name, bytes);
      } catch (error) {
        throw FormatException(
          error is FormatException
              ? error.message
              : 'Không đọc được tệp. Hãy lưu lại dạng XLSX hoặc CSV.',
        );
      }
    }
    final port = ReceivePort();
    Isolate? worker;
    try {
      worker = await Isolate.spawn(_parseWorker, (port.sendPort, name, bytes));
      final message = await port.first.timeout(const Duration(seconds: 30));
      if (message is _ParsedFile) return message;
      throw FormatException(message.toString());
    } on TimeoutException {
      throw const FormatException(
        'Tệp xử lý quá 30 giây. Hãy chọn tệp nhỏ hơn.',
      );
    } finally {
      worker?.kill(priority: Isolate.immediate);
      port.close();
    }
  }

  static void _parseWorker((SendPort, String, Uint8List) input) {
    try {
      input.$1.send(_parse(input.$2, input.$3));
    } catch (error) {
      input.$1.send(
        error is FormatException
            ? error.message
            : 'Không đọc được tệp. Hãy lưu lại dạng XLSX hoặc CSV.',
      );
    }
  }

  /// Synchronous entry point for deterministic parser tests; device picker uses an isolate.
  static UploadedFileInfo processFileBytes({
    required SourceSide side,
    required String fileName,
    required Uint8List bytes,
  }) => _register(side, _parse(fileName, bytes));
  static final _digitsOnly = RegExp(r'\d');
  static final _zerosOnly = RegExp(r'^0+$');
  static final _dateLetterPattern = RegExp(r'[dy]', caseSensitive: false);
  static final _quotedPattern = RegExp(r'"[^"]*"');
  static final _sheetNamePattern = RegExp(r'^xl/worksheets/sheet\d+\.xml$');

  static UploadedFileInfo _register(SourceSide side, _ParsedFile parsed) {
    _files.removeWhere((k, _) => k.endsWith('_${side.name}'));
    _selected.removeWhere((k, _) => k.endsWith('_${side.name}'));
    final ref =
        'userfile:${DateTime.now().microsecondsSinceEpoch}_${side.name}';
    _files[ref] = parsed;
    return selectSheet(ref, parsed.tables.keys.first);
  }

  static UploadedFileInfo? info(String ref) {
    if (ref == 'fixture:a' || ref == 'fixture:b') {
      final isA = ref == 'fixture:a';
      final name = _selected[ref] ?? 'Sheet 1 (Doanh thu)';
      return UploadedFileInfo(
        fileName: isA ? 'sample_a.xlsx' : 'sample_b.xlsx',
        format: SourceFormat.xlsx,
        privateRef: ref,
        rowCount: 4,
        columnCount: 2,
        sheets: const ['Sheet 1 (Doanh thu)', 'Sheet 2 (Chi phí)'],
        sheetName: name,
      );
    }
    final file = _files[ref];
    if (file == null) return null;
    final name = _selected[ref] ?? file.tables.keys.first,
        table = file.tables[name]!;
    return UploadedFileInfo(
      fileName: file.name,
      format: file.format,
      privateRef: ref,
      rowCount: table.rows.length,
      columnCount: table.headers.length,
      sha256Digest: file.sha256Digest,
      sheets: file.format == SourceFormat.xlsx
          ? file.tables.keys.toList()
          : const [],
      sheetName: file.format == SourceFormat.xlsx ? name : null,
    );
  }

  static String? sha256Of(String ref) => _files[ref]?.sha256Digest;

  /// Returns estimated byte size of currently loaded in-memory files.
  static int estimatedMemoryBytes() {
    int total = 0;
    for (final file in _files.values) {
      total += file.name.length * 2;
      for (final table in file.tables.values) {
        for (final h in table.headers) {
          total += h.length * 2;
        }
        for (final row in table.rows) {
          for (final cell in row) {
            total += cell.length * 2 + 8;
          }
        }
        for (final sc in table.specialCells.values) {
          total += (sc.imageBytes?.length ?? 0) + (sc.rawLexeme?.length ?? 0) * 2;
        }
      }
    }
    return total;
  }

  static UploadedFileInfo selectSheet(String ref, String name) {
    if (ref == 'fixture:a' || ref == 'fixture:b') {
      _selected[ref] = name;
      final isSheet2 = name.contains('2') || name.contains('Chi phí');
      final isA = ref == 'fixture:a';
      final vals = isSheet2
          ? (isA
                ? [
                    ['E01', '50.0'],
                    ['E02', '120.0'],
                    ['E03', '85.5'],
                  ]
                : [
                    ['E01', '50.0'],
                    ['E02', '135.0'],
                    ['E03', '85.5'],
                  ])
          : (isA ? DemoInputPort.valuesA : DemoInputPort.valuesB);
      final flds = isSheet2
          ? [
              const TableField('id', 'Mã chi phí'),
              const TableField('amount', 'Số tiền'),
            ]
          : DemoInputPort.fields;
      DemoInputPort.registerUserFile(
        ref,
        fileName: isA ? 'sample_a.xlsx' : 'sample_b.xlsx',
        format: SourceFormat.xlsx,
        fields: flds,
        values: vals,
        sheetName: name,
        headerRow: 1,
      );
      return info(ref)!;
    }
    final file = _files[ref];
    final table = file?.tables[name];
    if (file == null || table == null) {
      throw const FormatException('Không tìm thấy sheet dữ liệu.');
    }
    _selected[ref] = name;
    DemoInputPort.registerUserFile(
      ref,
      fileName: file.name,
      format: file.format,
      fields: table.headers.map((h) => TableField(h, h)).toList(),
      values: table.rows,
      sheetName: file.format == SourceFormat.xlsx ? name : null,
      headerRow: table.headerRow,
    );
    return info(ref)!;
  }

  /// The selected tab is only a preview; this inventory freezes all worksheets.
  static InputSnapshot? snapshot(
    String ref,
    SourceArtifact artifact,
    ImportBinding binding,
  ) {
    final file = _files[ref];
    if (file == null) return null;
    return _buildSnapshot(
      file,
      _selected[ref] ?? file.tables.keys.first,
      artifact,
      binding,
    );
  }

  static Future<InputSnapshot?> snapshotInBackground(
    String ref,
    SourceArtifact artifact,
    ImportBinding binding,
  ) async {
    final file = _files[ref];
    if (file == null) return null;
    final selected = _selected[ref] ?? file.tables.keys.first;
    return kIsWeb
        ? _buildSnapshot(file, selected, artifact, binding)
        : Isolate.run(() => _buildSnapshot(file, selected, artifact, binding));
  }

  static InputSnapshot _buildSnapshot(
    _ParsedFile file,
    String selectedName,
    SourceArtifact artifact,
    ImportBinding binding,
  ) {
    InputSnapshot build(
      String name,
      _ParsedTable t,
      int sheetIndex,
    ) => InputSnapshot(
      id: '${artifact.id}-sheet-$sheetIndex-${binding.revision}-${binding.attempt}',
      binding: binding,
      sheetName: file.format == SourceFormat.xlsx ? name : null,
      fields: t.headers.map((h) => TableField(h, h)),
      fullValidation: true,
      ocrReviewed: false,
      warnings: t.warnings,
      records: [
        for (var r = 0; r < t.rows.length; r++)
          TableRecord(
            '${artifact.id}-sheet-$sheetIndex-row-$r',
            r,
            {
              for (var c = 0; c < t.headers.length; c++)
                t.headers[c]:
                    t.specialCells['$r,$c'] ??
                    SourceCell(CellKind.text, rawLexeme: t.rows[r][c]),
            },
            {
              for (var c = 0; c < t.headers.length; c++)
                t.headers[c]:
                    '$name!${_columnLetters(c + 1)}${r < t.sourceRows.length ? t.sourceRows[r] : r + t.headerRow + 1}',
            },
          ),
      ],
    );
    final entries = file.tables.entries.toList(),
        sheets = [
          for (var i = 0; i < entries.length; i++)
            build(entries[i].key, entries[i].value, i),
        ];
    final selected = sheets[entries.indexWhere((e) => e.key == selectedName)];
    return InputSnapshot(
      id: selected.id,
      binding: binding,
      fields: selected.fields,
      records: selected.records,
      fullValidation: true,
      ocrReviewed: false,
      sheetName: selected.sheetName,
      workbookSheets: file.format == SourceFormat.xlsx ? sheets : const [],
      warnings: sheets.expand((s) => s.warnings),
    );
  }

  static String _columnLetters(int column) {
    var out = '';
    while (column > 0) {
      column--;
      out = String.fromCharCode(65 + column % 26) + out;
      column ~/= 26;
    }
    return out;
  }

  static final _cellAddressPattern = RegExp(
    r'^(\$?)([A-Za-z]{1,3})(\$?)(\d+)$',
  );

  static ({int row, int col})? _parseCellAddress(String raw) {
    final m = _cellAddressPattern.firstMatch(raw.trim());
    if (m == null) return null;
    var col = 0;
    for (final code in m.group(2)!.toUpperCase().codeUnits) {
      col = col * 26 + code - 64;
    }
    final row = int.tryParse(m.group(4)!);
    if (row == null || row <= 0 || col <= 0) return null;
    return (row: row, col: col - 1);
  }

  static ({int startRow, int startCol, int endRow, int endCol})?
  _parseCellRange(String? ref) {
    if (ref == null || !ref.contains(':')) return null;
    final parts = ref.split(':');
    if (parts.length != 2) return null;
    final a = _parseCellAddress(parts[0]);
    final b = _parseCellAddress(parts[1]);
    if (a == null || b == null) return null;
    return (
      startRow: a.row < b.row ? a.row : b.row,
      startCol: a.col < b.col ? a.col : b.col,
      endRow: a.row > b.row ? a.row : b.row,
      endCol: a.col > b.col ? a.col : b.col,
    );
  }

  /// Normalizes formula syntax (strip leading `=`, strip `_xlfn.`/`_xlws.`
  /// prefixes, normalize semicolon `;` argument separators outside string
  /// literals to `,` so `=SUM(A1;B2)` and `=SUM(A1,B2)` normalize consistently).
  static String _normalizeFormula(String formula) {
    var cleaned = formula.trim();
    if (cleaned.startsWith('=')) {
      cleaned = cleaned.substring(1).trim();
    }
    cleaned = cleaned.replaceAll(
      RegExp(r'\b(?:_xlfn|_xlws)\.', caseSensitive: false),
      '',
    );
    final buf = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < cleaned.length; i++) {
      final ch = cleaned[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
        buf.write(ch);
      } else if (ch == ';' && !inQuotes) {
        buf.write(',');
      } else {
        buf.write(ch);
      }
    }
    return buf.toString();
  }

  /// Shifts relative A1 cell references in a master shared formula by
  /// ([rowDelta], [colDelta]).
  static String _shiftSharedFormula(
    String masterFormula,
    int rowDelta,
    int colDelta,
  ) {
    if (rowDelta == 0 && colDelta == 0) return masterFormula;
    return masterFormula.replaceAllMapped(
      RegExp(r'(\$?)([A-Za-z]{1,3})(\$?)(\d+)(?!\s*\()'),
      (m) {
        final lockCol = m.group(1) == r'$';
        final colLetters = m.group(2)!.toUpperCase();
        final lockRow = m.group(3) == r'$';
        final rowNum = int.tryParse(m.group(4)!);
        if (rowNum == null) return m.group(0)!;
        var col = 0;
        for (final code in colLetters.codeUnits) {
          col = col * 26 + code - 64;
        }
        final nextCol = lockCol ? col : (col + colDelta).clamp(1, maxColumns);
        final nextRow = lockRow ? rowNum : (rowNum + rowDelta).clamp(1, maxRows);
        return '${lockCol ? r'$' : ''}${_columnLetters(nextCol)}'
            '${lockRow ? r'$' : ''}$nextRow';
      },
    );
  }

  static void release(String ref) {
    _files.remove(ref);
    _selected.remove(ref);
    DemoInputPort.forgetUserFile(ref);
  }

  static void clear() {
    _files.clear();
    _selected.clear();
    DemoInputPort.clearUserFiles();
  }

  static _ParsedFile _parse(String name, Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maxFileBytes) {
      throw const FormatException('Tệp phải có dữ liệu và không vượt 500 MB.');
    }
    final digest = sha256.convert(bytes).toString();
    final parsed = _parseBody(name, bytes);
    return _ParsedFile(
      parsed.name,
      parsed.format,
      parsed.tables,
      sha256Digest: digest,
    );
  }

  static _ParsedFile _parseBody(String name, Uint8List bytes) {
    final ext = name.split('.').last.toLowerCase();
    if (!{'csv', 'tsv', 'txt', 'json', 'xlsx'}.contains(ext)) {
      throw const FormatException(
        'Chỉ hỗ trợ XLSX, CSV, TSV, TXT và JSON. Hãy lưu XLS cũ thành XLSX.',
      );
    }
    if (ext == 'xlsx') return _xlsx(name, bytes);
    final text = utf8.decode(bytes).replaceFirst('\ufeff', '');
    if (ext == 'json') {
      final json = jsonDecode(text);
      List<String> headers;
      List<List<String>> rows;
      String cell(Object? v) {
        if (v is Map || v is List) {
          throw const FormatException('Ô JSON phải là giá trị đơn.');
        }
        return v?.toString() ?? '';
      }

      if (json is List && json.isNotEmpty && json.every((r) => r is Map)) {
        headers = {
          for (final row in json) ...(row as Map).keys.map((k) => k.toString()),
        }.toList();
        rows = json
            .map((r) => headers.map((h) => cell(r[h])).toList())
            .toList();
      } else if (json is Map &&
          json['headers'] is List &&
          json['rows'] is List) {
        headers = (json['headers'] as List).map(cell).toList();
        rows = (json['rows'] as List).map((r) {
          if (r is! List) {
            throw const FormatException('Dòng JSON phải là mảng.');
          }
          return r.map(cell).toList();
        }).toList();
      } else {
        throw const FormatException(
          'JSON cần là mảng bản ghi hoặc {headers, rows}.',
        );
      }
      return _ParsedFile(name, SourceFormat.json, {
        'Data': _validate(headers, rows, 1),
      });
    }
    final first = text.split(RegExp(r'\r?\n')).first;
    int count(String d) => d.allMatches(first).length;
    final delimiter = ext == 'tsv'
        ? '\t'
        : count('\t') >= count(',') &&
              count('\t') >= count(';') &&
              count('\t') > 0
        ? '\t'
        : count(';') > count(',')
        ? ';'
        : ',';
    final parsed = CsvDecoder(fieldDelimiter: delimiter, dynamicTyping: false)
        .convert(text.replaceAll('\r\n', '\n').replaceAll('\r', '\n'))
        .map((r) => r.map((v) => v.toString()).toList())
        .where((r) => r.any((v) => v.trim().isNotEmpty))
        .toList();
    if (parsed.isEmpty) {
      throw const FormatException('Tệp không có tiêu đề cột.');
    }
    return _ParsedFile(
      name,
      ext == 'tsv' ? SourceFormat.tsv : SourceFormat.csv,
      {'Data': _validate(parsed.first, parsed.skip(1).toList(), 1)},
    );
  }

  static _ParsedTable _validate(
    List<String> headers,
    List<List<String>> rows,
    int headerRow, {
    bool repair = false,
  }) {
    headers = headers.map((v) => v.replaceFirst('\ufeff', '').trim()).toList();
    if (repair) {
      final used = <String>{};
      headers = [
        for (var c = 0; c < headers.length; c++)
          (() {
            final base = headers[c].isEmpty ? 'Cột ${c + 1}' : headers[c];
            var h = base, n = 1;
            while (used.contains(h)) {
              h = '$base (${++n})';
            }
            used.add(h);
            return h;
          })(),
      ];
    }
    if (headers.isEmpty ||
        headers.any((h) => h.isEmpty) ||
        headers.toSet().length != headers.length) {
      throw const FormatException(
        'Tiêu đề cột phải có tên duy nhất và không để trống.',
      );
    }
    if (headers.length > maxColumns ||
        rows.length > maxRows ||
        rows.length * headers.length > maxCells) {
      throw const FormatException('Tệp vượt giới hạn dòng, cột hoặc ô.');
    }
    for (final row in rows) {
      if (row.length > headers.length) {
        throw const FormatException('Có dòng chứa nhiều ô hơn tiêu đề cột.');
      }
      if (row.any((v) => v.length > 32767)) {
        throw const FormatException('Nội dung một ô vượt 32.767 ký tự.');
      }
      while (row.length < headers.length) {
        row.add('');
      }
    }
    return _ParsedTable(headers, rows, headerRow);
  }

  static _ParsedFile _xlsx(String name, Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    if (archive.files.length > 20000 ||
        archive.files.fold<int>(0, (n, f) => n + f.size) > 1500 * 1024 * 1024 ||
        archive.files.any((f) => f.size > 500 * 1024 * 1024)) {
      throw const FormatException('Workbook vượt giới hạn giải nén.');
    }
    XmlDocument? doc(String path) {
      final file = archive.findFile(path);
      return file == null ? null : XmlDocument.parse(utf8.decode(file.content));
    }

    Iterable<XmlElement> elements(XmlNode? node, String name) =>
        node?.descendants.whereType<XmlElement>().where(
          (e) => e.name.local == name,
        ) ??
        const [];
    String text(XmlNode node, String name) =>
        elements(node, name).map((e) => e.innerText).join();
    final content = inspectXlsxCellContent(archive);
    final strings = elements(
      doc('xl/sharedStrings.xml'),
      'si',
    ).map((si) => text(si, 't')).toList();
    final styles = doc('xl/styles.xml');
    final formats = <int, String>{
      for (final f in elements(styles, 'numFmt'))
        int.parse(f.getAttribute('numFmtId')!):
            f.getAttribute('formatCode') ?? '',
    };
    final xfs = elements(styles, 'cellXfs').firstOrNull;
    final styleIds = xfs == null
        ? <int>[]
        : elements(xfs, 'xf')
              .map((e) => int.tryParse(e.getAttribute('numFmtId') ?? '') ?? 0)
              .toList();
    XmlElement? directChild(XmlElement parent, String localName) {
      for (final child in parent.childElements) {
        if (child.name.local == localName) return child;
      }
      return null;
    }

    final relDoc = doc('xl/_rels/workbook.xml.rels');
    final relList = elements(relDoc, 'Relationship').toList();
    final rels = <String, String>{
      for (final r in relList)
        r.getAttribute('Id') ?? '': r.getAttribute('Target') ?? '',
    };
    final worksheetRelIds = <String>{
      for (final r in relList)
        if ((r.getAttribute('Type') ?? '').isEmpty ||
            (r.getAttribute('Type') ?? '').endsWith('/worksheet'))
          r.getAttribute('Id') ?? '',
    };
    final workbook = doc('xl/workbook.xml');
    final date1904 =
        elements(
          workbook,
          'workbookPr',
        ).firstOrNull?.getAttribute('date1904') ==
        '1';
    final sheets = <String, String>{};
    for (final sheet in elements(workbook, 'sheet')) {
      final id = sheet.attributes
          .where((a) => a.name.local == 'id')
          .firstOrNull
          ?.value;
      if (id == null || !worksheetRelIds.contains(id)) {
        continue;
      }
      var path = rels[id];
      if (path == null) continue;
      path = resolveXlsxPart('xl/workbook.xml', path);
      if (path == null) {
        throw const FormatException('Đường dẫn sheet không hợp lệ.');
      }
      sheets[sheet.getAttribute('name') ?? 'Sheet ${sheets.length + 1}'] = path;
    }
    if (sheets.isEmpty && workbook == null) {
      for (final f in archive.files.where(
        (f) => _sheetNamePattern.hasMatch(f.name),
      )) {
        sheets['Sheet ${sheets.length + 1}'] = f.name;
      }
    }
    final tables = <String, _ParsedTable>{};
    for (final entry in sheets.entries) {
      final sheet = doc(entry.value);
      if (sheet == null) {
        throw const FormatException(
          'Thiếu worksheet được workbook tham chiếu.',
        );
      }
      final mergedNonAnchors = <(int, int)>{};
      for (final mc in elements(sheet, 'mergeCell')) {
        final ref = mc.getAttribute('ref');
        final range = _parseCellRange(ref);
        if (range != null) {
          for (var r = range.startRow; r <= range.endRow; r++) {
            for (var c = range.startCol; c <= range.endCol; c++) {
              if (r != range.startRow || c != range.startCol) {
                mergedNonAnchors.add((r, c));
              }
            }
          }
        }
      }
      final sharedFormulas = <String, ({int baseRow, int baseCol, String formula})>{};
      final specialContent = content[entry.key];
      final sparse = <int, Map<int, String>>{};
      final sparseSpecial = <String, SourceCell>{};
      var width = 0;
      for (final row in elements(sheet, 'row')) {
        final ri =
            int.tryParse(row.getAttribute('r') ?? '') ?? sparse.length + 1;
        if (ri > maxRows + 1) {
          throw const FormatException('Sheet vượt giới hạn dòng.');
        }
        final values = <int, String>{};
        for (final c in row.childElements.where((e) => e.name.local == 'c')) {
          final letters =
              (c.getAttribute('r') ?? '').replaceAll(_digitsOnly, '');
          var col = 0;
          for (final code in letters.toUpperCase().codeUnits) {
            col = col * 26 + code - 64;
          }
          col = col == 0 ? values.length : col - 1;
          if (col >= maxColumns) {
            throw const FormatException('Sheet vượt giới hạn cột.');
          }
          final fElem = directChild(c, 'f');
          String? formulaText;
          if (fElem != null) {
            final fType = fElem.getAttribute('t');
            final si = fElem.getAttribute('si');
            final rawFormula = fElem.innerText.trim();
            if (fType == 'shared' && si != null) {
              if (rawFormula.isNotEmpty) {
                sharedFormulas[si] = (
                  baseRow: ri,
                  baseCol: col,
                  formula: rawFormula,
                );
                formulaText = rawFormula;
              } else {
                final master = sharedFormulas[si];
                if (master != null) {
                  formulaText = _shiftSharedFormula(
                    master.formula,
                    ri - master.baseRow,
                    col - master.baseCol,
                  );
                }
              }
            } else if (rawFormula.isNotEmpty) {
              formulaText = rawFormula;
            }
          }
          if (mergedNonAnchors.contains((ri, col))) {
            if (col + 1 > width) width = col + 1;
            continue;
          }
          final t = c.getAttribute('t');
          final vElem = directChild(c, 'v');
          final v = vElem?.innerText ?? '';
          var value = v;
          if (t == 's') {
            final i = int.tryParse(v);
            if (i == null || i < 0 || i >= strings.length) {
              throw const FormatException('Shared string không hợp lệ.');
            }
            value = strings[i];
          } else if (t == 'inlineStr') {
            final isElem = directChild(c, 'is');
            final tElem =
                isElem != null ? directChild(isElem, 't') : directChild(c, 't');
            value = tElem?.innerText ?? text(c, 't');
          } else if (t == 'b') {
            value = v == '1' ? 'true' : 'false';
          } else if (t == 'str' || t == 'e') {
            value = v.isNotEmpty
                ? v
                : (formulaText != null ? '=${_normalizeFormula(formulaText)}' : '');
          } else {
            if (formulaText != null && v.isEmpty) {
              value = '=${_normalizeFormula(formulaText)}';
            } else if (t == null || t == 'n') {
              final s = int.tryParse(c.getAttribute('s') ?? '') ?? -1;
              final fmt = s >= 0 && s < styleIds.length ? styleIds[s] : 0,
                  number = double.tryParse(v);
              final code = formats[fmt] ?? '';
              if (number != null) {
                if (_zerosOnly.hasMatch(code)) {
                  value = number.toInt().toString().padLeft(code.length, '0');
                } else if (code.contains('%') || fmt == 9 || fmt == 10) {
                  final percent = number * 100;
                  value =
                      '${percent == percent.truncateToDouble() ? percent.toInt() : percent}%';
                } else if ((fmt >= 14 && fmt <= 22) ||
                    _dateLetterPattern
                        .hasMatch(code.replaceAll(_quotedPattern, 'null'))) {
                  final date = DateTime.utc(
                    date1904 ? 1904 : 1899,
                    date1904 ? 1 : 12,
                    date1904 ? 1 : 30,
                  ).add(Duration(milliseconds: (number * 86400000).round()));
                  value = date.toIso8601String().substring(0, 10);
                }
              }
            }
          }
          final special = specialContent?.cells[c.getAttribute('r')];
          if (special != null) {
            if (special.kind == CellKind.image &&
                special.imagePlacement == 'drawingAnchor' &&
                value.trim().isNotEmpty) {
              // Cell already has its own text/number value; keep floating image if cell is blank, or let cell value coexist
              value = special.rawLexeme ?? value;
            } else {
              value = special.rawLexeme ?? '';
            }
            sparseSpecial['$ri,$col'] = special;
          }
          if (value.length > 32767) {
            throw const FormatException('Nội dung một ô vượt 32.767 ký tự.');
          }
          values[col] = value;
          if (col + 1 > width) width = col + 1;
        }
        if (values.isNotEmpty) sparse[ri] = values;
      }
      if (specialContent != null) {
        final baseMaxCol = width > 0 ? width - 1 : 0;
        for (final entryCell in specialContent.cells.entries) {
          final parsedAddr = _parseCellAddress(entryCell.key);
          if (parsedAddr == null) continue;
          final ri = parsedAddr.row;
          var col = parsedAddr.col;
          if (ri > maxRows + 1 || col >= maxColumns) continue;
          if (mergedNonAnchors.contains((ri, col))) continue;
          // If a floating Place over Cells image is anchored far beyond the
          // sheet's actual column span (e.g. S2 on an 8-column table), clamp it
          // so we don't invent dozens of blank columns.
          if (entryCell.value.imagePlacement == 'drawingAnchor' &&
              baseMaxCol > 0 &&
              col > baseMaxCol + 1) {
            col = baseMaxCol;
          }
          if (!sparseSpecial.containsKey('$ri,$col')) {
            final rowMap = sparse.putIfAbsent(ri, () => <int, String>{});
            final lex = entryCell.value.rawLexeme ?? '';
            if ((rowMap[col] ?? '').isEmpty) {
              rowMap[col] = lex;
            }
            sparseSpecial['$ri,$col'] = entryCell.value;
            if (col + 1 > width) width = col + 1;
          }
        }
      }
      if (sparse.isEmpty) {
        tables[entry.key] = _ParsedTable(
          [],
          [],
          0,
          warnings: specialContent?.warnings ?? const [],
        );
        continue;
      }
      if (sparse.length * width > maxCells) {
        throw const FormatException('Sheet vượt giới hạn số ô.');
      }
      List<String> rowAt(int r) =>
          List.generate(width, (c) => sparse[r]?[c] ?? '');
      var header = 1;
      List<String> headers = [];
      for (var r = 1; r <= 15; r++) {
        final row = rowAt(r).map((v) => v.trim()).toList();
        while (row.isNotEmpty && row.last.isEmpty) {
          row.removeLast();
        }
        if (row.isEmpty) continue;
        final numeric = row
            .where(
              (v) =>
                  RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(v) ||
                  num.tryParse(v) != null,
            )
            .length;
        if (row.every((v) => v.isNotEmpty) &&
            row.toSet().length == row.length &&
            numeric < (row.length / 2).ceil() &&
            !sparseSpecial.entries.any(
              (e) =>
                  e.key.startsWith('$r,') &&
                  e.value.imagePlacement != 'drawingAnchor',
            ) &&
            sparse[r + 1]?.values.any((v) => v.isNotEmpty) == true) {
          header = r;
          headers = row;
          break;
        }
      }
      if (headers.isEmpty) {
        headers = rowAt(1);
        while (headers.isNotEmpty && headers.last.isEmpty) {
          headers.removeLast();
        }
      }
      if (sparseSpecial.entries.any(
        (e) =>
            e.key.startsWith('1,') &&
            e.value.imagePlacement != 'drawingAnchor',
      )) {
        header = 0;
        headers = List.filled(width, '', growable: true);
      }
      var dataWidth = headers.length;
      for (final row in sparse.entries.where((e) => e.key > header)) {
        for (final cell in row.value.entries) {
          if (cell.value.isNotEmpty && cell.key + 1 > dataWidth) {
            dataWidth = cell.key + 1;
          }
        }
      }
      while (headers.length < dataWidth) {
        headers.add('');
      }
      final rows = <List<String>>[],
          sourceRows = <int>[],
          specialCells = <String, SourceCell>{};
      for (final r in sparse.keys.where((r) => r > header).toList()..sort()) {
        final row = List.generate(headers.length, (c) => sparse[r]?[c] ?? '');
        if (row.any((v) => v.isNotEmpty)) {
          for (var c = 0; c < headers.length; c++) {
            final special = sparseSpecial['$r,$c'];
            if (special != null) specialCells['${rows.length},$c'] = special;
          }
          sourceRows.add(r);
          rows.add(row);
        }
      }
      final validated = _validate(headers, rows, header, repair: true);
      tables[entry.key] = _ParsedTable(
        validated.headers,
        validated.rows,
        header,
        sourceRows: sourceRows,
        specialCells: specialCells,
        warnings: specialContent?.warnings ?? const [],
      );
    }
    if (tables.isEmpty) {
      throw const FormatException('Workbook không có sheet dữ liệu hiển thị.');
    }
    if (tables.values.fold<int>(0, (n, t) => n + t.rows.length) > maxRows ||
        tables.values.fold<int>(
              0,
              (n, t) => n + t.rows.length * t.headers.length,
            ) >
            maxCells) {
      throw const FormatException(
        'Toàn workbook vượt giới hạn dòng hoặc số ô.',
      );
    }
    return _ParsedFile(name, SourceFormat.xlsx, tables);
  }
}
