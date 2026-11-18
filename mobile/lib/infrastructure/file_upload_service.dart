import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:xml/xml.dart';

import '../domain/workflow.dart';
import 'demo/demo_workflow_ports.dart';

final class UploadedFileInfo {
  final String fileName;
  final SourceFormat format;
  final String privateRef;
  final int rowCount;
  final int columnCount;

  const UploadedFileInfo({
    required this.fileName,
    required this.format,
    required this.privateRef,
    required this.rowCount,
    required this.columnCount,
  });
}

abstract final class MobileFileUploadService {
  /// Opens device native file picker and parses CSV / TSV / XLSX into memory.
  static Future<UploadedFileInfo?> pickAndProcessFile(SourceSide side) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'tsv', 'txt', 'xlsx', 'xls'],
    );

    if (files.isEmpty) {
      return null;
    }

    final file = files.first;
    final fileName = file.name;

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('Tệp trống hoặc không thể đọc dữ liệu.');
    }

    return processFileBytes(
      side: side,
      fileName: fileName,
      bytes: bytes,
    );
  }

  /// Parses raw file bytes and registers them with [DemoInputPort].
  static UploadedFileInfo processFileBytes({
    required SourceSide side,
    required String fileName,
    required Uint8List bytes,
  }) {
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';

    List<TableField> fields = [];
    List<List<String>> rows = [];
    SourceFormat format = SourceFormat.csv;

    if (ext == 'xlsx' || ext == 'xls') {
      format = SourceFormat.xlsx;
      try {
        final excel = Excel.decodeBytes(bytes);
        if (excel.tables.isEmpty) {
          throw Exception('Tệp Excel không chứa sheet dữ liệu nào.');
        }

        Sheet? targetSheet;
        for (final table in excel.tables.values) {
          if (table.maxRows > 0) {
            targetSheet = table;
            break;
          }
        }
        targetSheet ??= excel.tables.values.first;

        final maxRows = targetSheet.maxRows;
        final maxCols = targetSheet.maxColumns;

        if (maxRows == 0) {
          throw Exception('Sheet Excel không có dữ liệu.');
        }

        final rawHeaders = <String>[];
        for (var c = 0; c < maxCols; c++) {
          final cell = targetSheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0),
          );
          final val = cell.value?.toString().trim() ?? '';
          rawHeaders.add(val.isEmpty ? 'Cột ${c + 1}' : val);
        }

        final seen = <String, int>{};
        fields = rawHeaders.map((h) {
          var name = h;
          if (seen.containsKey(name)) {
            seen[name] = seen[name]! + 1;
            name = '$name (${seen[name]})';
          } else {
            seen[name] = 1;
          }
          return TableField(name, name);
        }).toList();

        for (var r = 1; r < maxRows; r++) {
          final rowData = <String>[];
          var hasData = false;
          for (var c = 0; c < maxCols; c++) {
            final cell = targetSheet.cell(
              CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r),
            );
            final val = cell.value?.toString() ?? '';
            if (val.trim().isNotEmpty) hasData = true;
            rowData.add(val);
          }
          if (hasData) {
            rows.add(rowData);
          }
        }
      } catch (e) {
        // Fallback for files where Excel.decodeBytes fails (e.g. "Damaged Excel file: styles",
        // missing/corrupted styles.xml, non-standard OpenXML, or HTML table disguised as .xls)
        final fallback = _parseXlsxDirectXml(bytes);
        fields = fallback.fields;
        rows = fallback.rows;
      }
    } else {
      format = ext == 'tsv' ? SourceFormat.tsv : SourceFormat.csv;
      final text = utf8.decode(bytes, allowMalformed: true);
      final delimiter = ext == 'tsv'
          ? '\t'
          : (text.contains(';') && !text.contains(',') ? ';' : ',');
      final parsed = CsvDecoder(
        fieldDelimiter: delimiter,
        dynamicTyping: false,
      ).convert(
        text
            .replaceAll('\r\n', '\n')
            .replaceAll('\r', '\n'),
      );

      if (parsed.isEmpty) {
        throw Exception('Tệp bảng tính CSV trống.');
      }

      final rawHeaders = parsed.first.map((c) => c.toString().trim()).toList();
      final seen = <String, int>{};
      fields = rawHeaders.asMap().entries.map((entry) {
        var name = entry.value.isEmpty ? 'Cột ${entry.key + 1}' : entry.value;
        if (seen.containsKey(name)) {
          seen[name] = seen[name]! + 1;
          name = '$name (${seen[name]})';
        } else {
          seen[name] = 1;
        }
        return TableField(name, name);
      }).toList();

      for (var i = 1; i < parsed.length; i++) {
        final line = parsed[i];
        if (line.isEmpty) continue;
        final strRow = line.map((c) => c.toString()).toList();
        while (strRow.length < fields.length) {
          strRow.add('');
        }
        if (strRow.any((cell) => cell.trim().isNotEmpty)) {
          rows.add(strRow);
        }
      }
    }

    final ref = 'userfile:${DateTime.now().microsecondsSinceEpoch}_${side.name}';
    DemoInputPort.registerUserFile(
      ref,
      fileName: fileName,
      format: format,
      fields: fields,
      values: rows,
    );

    return UploadedFileInfo(
      fileName: fileName,
      format: format,
      privateRef: ref,
      rowCount: rows.length,
      columnCount: fields.length,
    );
  }

  /// Trực tiếp giải nén ZIP OpenXML và phân tích `sheet1.xml` + `sharedStrings.xml`.
  /// Bỏ qua hoàn toàn `styles.xml` để khắc phục triệt để lỗi "Damaged Excel file: styles".
  static ({List<TableField> fields, List<List<String>> rows}) _parseXlsxDirectXml(
    Uint8List bytes,
  ) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final sharedStrings = <String>[];
      final sharedStringsFile = archive.findFile('xl/sharedStrings.xml');
      if (sharedStringsFile != null) {
        final content = utf8.decode(sharedStringsFile.content, allowMalformed: true);
        final doc = XmlDocument.parse(content);
        for (final si in doc.findAllElements('si')) {
          final tList = si.findAllElements('t').map((e) => e.innerText).join();
          sharedStrings.add(tList);
        }
      }

      ArchiveFile? sheetFile = archive.findFile('xl/worksheets/sheet1.xml');
      if (sheetFile == null) {
        for (final file in archive.files) {
          if (file.name.startsWith('xl/worksheets/sheet') && file.name.endsWith('.xml')) {
            sheetFile = file;
            break;
          }
        }
      }
      if (sheetFile == null) {
        throw Exception('Không tìm thấy sheet dữ liệu trong tệp Excel.');
      }

      final sheetXml = utf8.decode(sheetFile.content, allowMalformed: true);
      final sheetDoc = XmlDocument.parse(sheetXml);
      final sheetRows = <Map<int, String>>[];
      var maxColIndex = 0;

      for (final rowElem in sheetDoc.findAllElements('row')) {
        final rowMap = <int, String>{};
        for (final cElem in rowElem.findElements('c')) {
          final rAttr = cElem.getAttribute('r');
          final tAttr = cElem.getAttribute('t');

          var colIndex = 0;
          if (rAttr != null) {
            colIndex = _columnLetterToIndex(rAttr.replaceAll(RegExp(r'[0-9]'), ''));
          }
          if (colIndex > maxColIndex) maxColIndex = colIndex;

          String cellVal = '';
          if (tAttr == 's') {
            final vElem = cElem.findElements('v').firstOrNull;
            if (vElem != null) {
              final sIndex = int.tryParse(vElem.innerText.trim()) ?? -1;
              if (sIndex >= 0 && sIndex < sharedStrings.length) {
                cellVal = sharedStrings[sIndex];
              }
            }
          } else if (tAttr == 'inlineStr') {
            cellVal = cElem.findAllElements('t').map((e) => e.innerText).join();
          } else {
            final vElem = cElem.findElements('v').firstOrNull;
            cellVal = vElem?.innerText.trim() ?? '';
          }

          rowMap[colIndex] = cellVal;
        }
        if (rowMap.isNotEmpty) {
          sheetRows.add(rowMap);
        }
      }

      if (sheetRows.isEmpty) {
        throw Exception('Sheet Excel không có dữ liệu.');
      }

      final totalCols = maxColIndex + 1;
      final headerMap = sheetRows.first;
      final rawHeaders = List.generate(totalCols, (c) => headerMap[c]?.trim() ?? '');
      final seen = <String, int>{};
      final fields = rawHeaders.asMap().entries.map((entry) {
        var name = entry.value.isEmpty ? 'Cột ${entry.key + 1}' : entry.value;
        if (seen.containsKey(name)) {
          seen[name] = seen[name]! + 1;
          name = '$name (${seen[name]})';
        } else {
          seen[name] = 1;
        }
        return TableField(name, name);
      }).toList();

      final rows = <List<String>>[];
      for (var i = 1; i < sheetRows.length; i++) {
        final rMap = sheetRows[i];
        final rowList = List.generate(fields.length, (c) => rMap[c] ?? '');
        if (rowList.any((val) => val.trim().isNotEmpty)) {
          rows.add(rowList);
        }
      }

      return (fields: fields, rows: rows);
    } catch (_) {
      // Fallback nếu tệp thực chất là bảng HTML hoặc CSV được lưu dưới đuôi .xls/.xlsx
      final text = utf8.decode(bytes, allowMalformed: true);
      if (text.contains('<table') || text.contains('<TABLE')) {
        return _parseHtmlTable(text);
      }
      return _parseCsvFallback(text);
    }
  }

  static int _columnLetterToIndex(String letters) {
    if (letters.isEmpty) return 0;
    var result = 0;
    final upper = letters.toUpperCase();
    for (var i = 0; i < upper.length; i++) {
      final code = upper.codeUnitAt(i);
      if (code >= 65 && code <= 90) {
        result = result * 26 + (code - 64);
      }
    }
    return result > 0 ? result - 1 : 0;
  }

  static ({List<TableField> fields, List<List<String>> rows}) _parseHtmlTable(String html) {
    final trRegex = RegExp(r'<tr[^>]*>(.*?)<\/tr>', caseSensitive: false, dotAll: true);
    final cellRegex = RegExp(r'<t[dh][^>]*>(.*?)<\/t[dh]>', caseSensitive: false, dotAll: true);
    final allRows = <List<String>>[];

    for (final trMatch in trRegex.allMatches(html)) {
      final trContent = trMatch.group(1) ?? '';
      final cells = cellRegex.allMatches(trContent).map((m) {
        return m.group(1)?.replaceAll(RegExp(r'<[^>]+>'), '').trim() ?? '';
      }).toList();
      if (cells.isNotEmpty) allRows.add(cells);
    }

    if (allRows.isEmpty) throw Exception('Không thể đọc dữ liệu bảng từ tệp.');
    final rawHeaders = allRows.first;
    final seen = <String, int>{};
    final fields = rawHeaders.asMap().entries.map((entry) {
      var name = entry.value.isEmpty ? 'Cột ${entry.key + 1}' : entry.value;
      if (seen.containsKey(name)) {
        seen[name] = seen[name]! + 1;
        name = '$name (${seen[name]})';
      } else {
        seen[name] = 1;
      }
      return TableField(name, name);
    }).toList();

    final rows = <List<String>>[];
    for (var i = 1; i < allRows.length; i++) {
      final line = allRows[i];
      while (line.length < fields.length) {
        line.add('');
      }
      if (line.any((c) => c.trim().isNotEmpty)) {
        rows.add(line);
      }
    }
    return (fields: fields, rows: rows);
  }

  static ({List<TableField> fields, List<List<String>> rows}) _parseCsvFallback(String text) {
    final delimiter = text.contains('\t')
        ? '\t'
        : (text.contains(';') && !text.contains(',') ? ';' : ',');
    final parsed = CsvDecoder(fieldDelimiter: delimiter, dynamicTyping: false)
        .convert(text.replaceAll('\r\n', '\n').replaceAll('\r', '\n'));
    if (parsed.isEmpty) throw Exception('Tệp không chứa dữ liệu hợp lệ.');
    final rawHeaders = parsed.first.map((c) => c.toString().trim()).toList();
    final seen = <String, int>{};
    final fields = rawHeaders.asMap().entries.map((entry) {
      var name = entry.value.isEmpty ? 'Cột ${entry.key + 1}' : entry.value;
      if (seen.containsKey(name)) {
        seen[name] = seen[name]! + 1;
        name = '$name (${seen[name]})';
      } else {
        seen[name] = 1;
      }
      return TableField(name, name);
    }).toList();

    final rows = <List<String>>[];
    for (var i = 1; i < parsed.length; i++) {
      final line = parsed[i].map((c) => c.toString()).toList();
      while (line.length < fields.length) {
        line.add('');
      }
      if (line.any((c) => c.trim().isNotEmpty)) {
        rows.add(line);
      }
    }
    return (fields: fields, rows: rows);
  }
}
