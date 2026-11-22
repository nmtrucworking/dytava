import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:xml/xml.dart';
import 'package:excelcompare_core/excelcompare_core.dart';

String? resolveXlsxPart(String owner, String? target) {
  if (target == null ||
      target.isEmpty ||
      RegExp(r'^[a-z][a-z\d+.-]*:', caseSensitive: false).hasMatch(target) ||
      RegExp(r'[\\?#]').hasMatch(target)) {
    return null;
  }
  final parts = target.startsWith('/')
      ? <String>[]
      : (owner.split('/')..removeLast());
  for (final p in target.split('/')) {
    if (p.isEmpty || p == '.') continue;
    if (p == '..') {
      if (parts.isEmpty) return null;
      parts.removeLast();
    } else {
      parts.add(p);
    }
  }
  return parts.join('/');
}

final class XlsxSheetContent {
  XlsxSheetContent(this.path, this.cells, this.warnings);
  final String path;
  final Map<String, SourceCell> cells;
  final List<String> warnings;
}

Map<String, XlsxSheetContent> inspectXlsxCellContent(Archive archive) {
  XmlDocument? doc(String? path) {
    final f = path == null ? null : archive.findFile(path);
    if (f == null) return null;
    final value = utf8.decode(f.content);
    if (value.contains('<!DOCTYPE')) {
      throw const FormatException('Không hỗ trợ DTD trong workbook.');
    }
    return XmlDocument.parse(value);
  }

  List<XmlElement> all(XmlNode? node, String name) =>
      node?.descendants
          .whereType<XmlElement>()
          .where((e) => e.name.local == name)
          .toList() ??
      [];
  List<XmlElement> child(XmlNode? node, String name) =>
      node?.children
          .whereType<XmlElement>()
          .where((e) => e.name.local == name)
          .toList() ??
      [];
  T? at<T>(List<T> list, int index) =>
      index < 0 || index >= list.length ? null : list[index];
  int index(String? value) => value != null && RegExp(r'^\d+$').hasMatch(value)
      ? int.tryParse(value) ?? -1
      : -1;
  String? attr(XmlElement? e, String name) =>
      e?.attributes.where((a) => a.name.local == name).firstOrNull?.value;
  Map<String, ({String? path, String type})> rels(String owner) {
    final parts = owner.split('/'), file = parts.removeLast();
    final path = [...parts, '_rels', '$file.rels'].join('/');
    return {
      for (final r in all(doc(path), 'Relationship'))
        r.getAttribute('Id') ?? '': (
          path: r.getAttribute('TargetMode') == 'External'
              ? null
              : resolveXlsxPart(owner, r.getAttribute('Target')),
          type: r.getAttribute('Type') ?? '',
        ),
    };
  }

  const workbookPath = 'xl/workbook.xml';
  String? related(String suffix, String fallback, List<String> owners) {
    for (final owner in owners) {
      for (final rel in rels(owner).values) {
        if (rel.type.endsWith('/$suffix')) return rel.path;
      }
    }
    return archive.findFile(fallback) == null ? null : fallback;
  }

  final metaPath = related('sheetMetadata', 'xl/metadata.xml', [workbookPath]),
      meta = doc(metaPath);
  final owners = [workbookPath, ?metaPath];
  final values = all(
    doc(related('rdRichValue', 'xl/richData/rdrichvalue.xml', owners)),
    'rv',
  );
  final structures = all(
    doc(
      related(
        'rdRichValueStructure',
        'xl/richData/rdrichvaluestructure.xml',
        owners,
      ),
    ),
    's',
  );
  final richRelPath = related(
    'richValueRel',
    'xl/richData/richValueRel.xml',
    owners,
  );
  final richIds = all(
    doc(richRelPath),
    'rel',
  ).map((n) => attr(n, 'id')).toList();
  final media = richRelPath == null
      ? <String, ({String? path, String type})>{}
      : rels(richRelPath);
  final types = all(meta, 'metadataType'),
      blocks = child(all(meta, 'valueMetadata').firstOrNull, 'bk'),
      futures = all(meta, 'futureMetadata');
  final images = <String, SourceCell>{};
  SourceCell unsupported(String reason) => SourceCell(
    CellKind.unsupported,
    rawLexeme: '[Chưa đọc được nội dung ô: $reason]',
    contentIssue: reason,
  );
  SourceCell richCell(String vm) {
    final block = at(blocks, index(vm) - 1);
    if (block == null) return unsupported('Metadata ô không hợp lệ');
    final rc = child(block, 'rc')
        .where(
          (n) =>
              at(types, index(n.getAttribute('t')) - 1)?.getAttribute('name') ==
              'XLRICHVALUE',
        )
        .firstOrNull;
    if (rc == null) return unsupported('Kiểu dữ liệu liên kết chưa hỗ trợ');
    final future = futures
        .where((n) => n.getAttribute('name') == 'XLRICHVALUE')
        .firstOrNull;
    final rvb = all(
      at(child(future, 'bk'), index(rc.getAttribute('v'))),
      'rvb',
    ).firstOrNull;
    final rv = at(values, index(rvb?.getAttribute('i'))),
        structure = at(structures, index(rv?.getAttribute('s')));
    if (structure?.getAttribute('t') != '_localImage') {
      return unsupported('Rich value chưa hỗ trợ hoặc thiếu cấu trúc ảnh');
    }
    final keys = child(structure, 'k'), vals = child(rv, 'v');
    final field = keys.indexWhere(
      (k) => k.getAttribute('n') == '_rvRel:LocalImageIdentifier',
    );
    final id = at(richIds, index(at(vals, field)?.innerText)), rel = media[id];
    final file = rel?.type.endsWith('/image') == true && rel?.path != null
        ? archive.findFile(rel!.path!)
        : null;
    if (file == null || file.size == 0) {
      return unsupported('Thiếu media hoặc ảnh là liên kết ngoài');
    }
    return images.putIfAbsent(rel!.path!, () {
      final bytes = List<int>.unmodifiable(file.content),
          digest = sha256.convert(bytes).toString();
      return SourceCell(
        CellKind.image,
        rawLexeme: '[Ảnh nhúng · SHA-256 $digest]',
        imageBytes: bytes,
        imageDigest: digest,
        mediaType: file.name.split('.').last.toLowerCase(),
      );
    });
  }

  final workbook = doc(workbookPath),
      workbookRels = rels(workbookPath),
      result = <String, XlsxSheetContent>{};
  for (final s in all(workbook, 'sheet')) {
    final rel = workbookRels[attr(s, 'id')];
    if (rel?.path == null) {
      throw const FormatException('Thiếu relationship của sheet.');
    }
    if (rel!.type.isNotEmpty && !rel.type.endsWith('/worksheet')) {
      throw const FormatException(
        'Loại sheet này chưa được hỗ trợ trong so sánh worksheet.',
      );
    }
    final sheet = doc(rel.path),
        name = s.getAttribute('name') ?? '',
        cells = <String, SourceCell>{},
        warnings = <String>[];
    if (name.trim().isEmpty || result.containsKey(name)) {
      throw const FormatException('Tên worksheet bị thiếu hoặc trùng.');
    }
    if (sheet == null) {
      throw const FormatException('Thiếu dữ liệu của worksheet.');
    }
    for (final c in all(sheet, 'c')) {
      final address = c.getAttribute('r');
      if (address == null) continue;
      final vm = c.getAttribute('vm'),
          formula = all(c, 'f').map((e) => e.innerText).join();
      if (vm != null) {
        cells[address] = richCell(vm);
      } else if (RegExp(
        r'(?:^|[^\w.])(?:_xlfn\.)?(?:_xlws\.)?(?:IMAGE|DISPIMG)\s*\(',
        caseSensitive: false,
      ).hasMatch(formula)) {
        cells[address] = unsupported(
          'Công thức ảnh/ảnh từ URL chưa có dữ liệu ảnh nhúng được xác thực',
        );
      }
    }
    if (all(sheet, 'drawing').isNotEmpty ||
        all(sheet, 'legacyDrawing').isNotEmpty) {
      warnings.add('$name: ảnh/đối tượng nổi chưa được so sánh như ô.');
    }
    if (all(sheet, 'oleObject').isNotEmpty) {
      warnings.add('$name: đối tượng OLE nhúng chưa được so sánh.');
    }
    if (all(sheet, 'mergeCell').isNotEmpty) {
      warnings.add('$name: ô gộp giữ giá trị tại ô neo; không tự điền xuống.');
    }
    if (s.getAttribute('state') == 'hidden' ||
        s.getAttribute('state') == 'veryHidden') {
      warnings.add('$name: sheet ẩn được đưa vào phạm vi toàn workbook.');
    }
    if (cells.values.any((c) => c.kind == CellKind.unsupported)) {
      warnings.add(
        '$name: có nội dung ô chưa đọc được; kết quả được giữ ở trạng thái chưa kết luận.',
      );
    }
    result[name] = XlsxSheetContent(rel.path!, cells, warnings);
  }
  return result;
}
