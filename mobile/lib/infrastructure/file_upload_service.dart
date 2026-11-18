import 'dart:convert';
import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:xml/xml.dart';

import '../domain/workflow.dart';
import 'demo/demo_workflow_ports.dart';

final class UploadedFileInfo {
  const UploadedFileInfo({
    required this.fileName,
    required this.format,
    required this.privateRef,
    required this.rowCount,
    required this.columnCount,
    this.sheets = const [],
    this.sheetName,
  });
  final String fileName, privateRef;
  final SourceFormat format;
  final int rowCount, columnCount;
  final List<String> sheets;
  final String? sheetName;
}

final class _ParsedTable {
  const _ParsedTable(this.headers, this.rows, this.headerRow);
  final List<String> headers;
  final List<List<String>> rows;
  final int headerRow;
}

final class _ParsedFile {
  const _ParsedFile(this.name, this.format, this.tables);
  final String name;
  final SourceFormat format;
  final Map<String, _ParsedTable> tables;
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
  static UploadedFileInfo _register(SourceSide side, _ParsedFile parsed) {
    final ref =
        'userfile:${DateTime.now().microsecondsSinceEpoch}_${side.name}';
    _files[ref] = parsed;
    return selectSheet(ref, parsed.tables.keys.first);
  }

  static UploadedFileInfo? info(String ref) {
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
      sheets: file.format == SourceFormat.xlsx
          ? file.tables.keys.toList()
          : const [],
      sheetName: file.format == SourceFormat.xlsx ? name : null,
    );
  }

  static UploadedFileInfo selectSheet(String ref, String name) {
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
    final rels = <String, String>{
      for (final r in elements(
        doc('xl/_rels/workbook.xml.rels'),
        'Relationship',
      ))
        r.getAttribute('Id') ?? '': r.getAttribute('Target') ?? '',
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
      if (sheet.getAttribute('state') == 'hidden' ||
          sheet.getAttribute('state') == 'veryHidden') {
        continue;
      }
      final id = sheet.attributes
          .where((a) => a.name.local == 'id')
          .firstOrNull
          ?.value;
      var path = rels[id];
      if (path == null) continue;
      path = path.startsWith('/')
          ? path.substring(1)
          : path.startsWith('xl/')
          ? path
          : 'xl/$path';
      if (path.contains('..')) {
        throw const FormatException('Đường dẫn sheet không hợp lệ.');
      }
      sheets[sheet.getAttribute('name') ?? 'Sheet ${sheets.length + 1}'] = path;
    }
    if (sheets.isEmpty && workbook == null) {
      for (final f in archive.files.where(
        (f) => RegExp(r'^xl/worksheets/sheet\d+\.xml$').hasMatch(f.name),
      )) {
        sheets['Sheet ${sheets.length + 1}'] = f.name;
      }
    }
    final tables = <String, _ParsedTable>{};
    for (final entry in sheets.entries) {
      final sheet = doc(entry.value);
      if (sheet == null) continue;
      final sparse = <int, Map<int, String>>{};
      var width = 0;
      for (final row in elements(sheet, 'row')) {
        final ri =
            int.tryParse(row.getAttribute('r') ?? '') ?? sparse.length + 1;
        if (ri > maxRows + 1) {
          throw const FormatException('Sheet vượt giới hạn dòng.');
        }
        final values = <int, String>{};
        for (final c in row.childElements.where((e) => e.name.local == 'c')) {
          final letters = (c.getAttribute('r') ?? '').replaceAll(
            RegExp(r'\d'),
            '',
          );
          var col = 0;
          for (final code in letters.toUpperCase().codeUnits) {
            col = col * 26 + code - 64;
          }
          col = col == 0 ? values.length : col - 1;
          if (col >= maxColumns) {
            throw const FormatException('Sheet vượt giới hạn cột.');
          }
          final t = c.getAttribute('t'), v = text(c, 'v');
          var value = v;
          if (t == 's') {
            final i = int.tryParse(v);
            if (i == null || i < 0 || i >= strings.length) {
              throw const FormatException('Shared string không hợp lệ.');
            }
            value = strings[i];
          } else if (t == 'inlineStr') {
            value = text(c, 't');
          } else if (t == 'b') {
            value = v == '1' ? 'true' : 'false';
          } else if (elements(c, 'f').isNotEmpty && v.isEmpty) {
            value = '=${text(c, 'f')}';
          } else if (t == null || t == 'n') {
            final s = int.tryParse(c.getAttribute('s') ?? '') ?? -1;
            final fmt = s >= 0 && s < styleIds.length ? styleIds[s] : 0,
                number = double.tryParse(v);
            final code = formats[fmt] ?? '';
            if (number != null) {
              if (RegExp(r'^0+$').hasMatch(code)) {
                value = number.toInt().toString().padLeft(code.length, '0');
              } else if (code.contains('%') || fmt == 9 || fmt == 10) {
                final percent = number * 100;
                value =
                    '${percent == percent.truncateToDouble() ? percent.toInt() : percent}%';
              } else if ((fmt >= 14 && fmt <= 22) ||
                  RegExp(
                    r'[dy]',
                    caseSensitive: false,
                  ).hasMatch(code.replaceAll(RegExp(r'"[^"]*"'), 'null'))) {
                final date = DateTime.utc(
                  date1904 ? 1904 : 1899,
                  date1904 ? 1 : 12,
                  date1904 ? 1 : 30,
                ).add(Duration(milliseconds: (number * 86400000).round()));
                value = date.toIso8601String().substring(0, 10);
              }
            }
          }
          if (value.length > 32767) {
            throw const FormatException('Nội dung một ô vượt 32.767 ký tự.');
          }
          values[col] = value;
          if (col + 1 > width) width = col + 1;
        }
        if (values.isNotEmpty) sparse[ri] = values;
      }
      if (sparse.isEmpty) continue;
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
      final rows = <List<String>>[];
      for (final r in sparse.keys.where((r) => r > header).toList()..sort()) {
        final row = List.generate(headers.length, (c) => sparse[r]?[c] ?? '');
        if (row.any((v) => v.isNotEmpty)) rows.add(row);
      }
      tables[entry.key] = _validate(headers, rows, header, repair: true);
    }
    if (tables.isEmpty) {
      throw const FormatException('Workbook không có sheet dữ liệu hiển thị.');
    }
    return _ParsedFile(name, SourceFormat.xlsx, tables);
  }
}
