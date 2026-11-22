/// Workbook pairing contract, mirrored by web/js/sheet-mapping.js.
String normalizeSheetLabel(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
bool isGenericSheetName(String value) =>
    normalizeSheetLabel(value).isEmpty ||
    RegExp(r'^(sheet|trang(?: tính)?|worksheet|tabelle|feuille|hoja)[ _-]*\d*$',
            caseSensitive: false)
        .hasMatch(normalizeSheetLabel(value));

final class SheetDescriptor {
  SheetDescriptor(this.name, Iterable<String> headers, [this.types = const []])
      : headers = headers.map(normalizeSheetLabel).toList();
  final String name;
  final List<String> headers, types;
}

final class SheetPair {
  const SheetPair(this.a, this.b, this.nameA, this.nameB, this.method,
      [this.score = 1]);
  final int? a, b;
  final String? nameA, nameB;
  final String method;
  final double score;
  String get id => 'sheet:${a ?? '-'}:${b ?? '-'}';
  String get label => '${a == null ? '(Không có)' : nameA?.isNotEmpty == true ? nameA : 'Bảng dữ liệu A'} ↔ ${b == null ? '(Không có)' : nameB?.isNotEmpty == true ? nameB : 'Bảng dữ liệu B'}';
}

final class SheetMappingPlan {
  const SheetMappingPlan(this.pairs, this.unresolvedA, this.unresolvedB);
  final List<SheetPair> pairs;
  final List<int> unresolvedA, unresolvedB;
  bool get complete => unresolvedA.isEmpty && unresolvedB.isEmpty;
}

double sheetStructureScore(SheetDescriptor a, SheetDescriptor b) {
  bool meaningful(String h) =>
      h.isNotEmpty &&
      !RegExp(r'^(cột|column|col)[ _-]*\d+(?: \(\d+\))?$', caseSensitive: false)
          .hasMatch(h);
  final ha = a.headers.where(meaningful).toSet(),
      hb = b.headers.where(meaningful).toSet(),
      overlap = ha.intersection(hb);
  if (ha.isEmpty || hb.isEmpty || overlap.isEmpty) return 0;
  final maxWidth =
      a.headers.length > b.headers.length ? a.headers.length : b.headers.length;
  final minWidth =
      a.headers.length < b.headers.length ? a.headers.length : b.headers.length;
  var known = 0, same = 0;
  for (final h in overlap) {
    final i = a.headers.indexOf(h), j = b.headers.indexOf(h);
    final x = i < a.types.length ? a.types[i] : 'empty',
        y = j < b.types.length ? b.types[j] : 'empty';
    if (x != 'empty' && y != 'empty') {
      known++;
      if (x == y) same++;
    }
  }
  return .75 * (2 * overlap.length / (ha.length + hb.length)) +
      .15 * (minWidth / (maxWidth == 0 ? 1 : maxWidth)) +
      .1 * (known > 0 ? same / known : .5);
}

SheetMappingPlan mapSheets(List<SheetDescriptor> a, List<SheetDescriptor> b,
    {List<(String?, String?)> overrides = const []}) {
  final ra = {for (var i = 0; i < a.length; i++) i},
      rb = {for (var i = 0; i < b.length; i++) i},
      pairs = <SheetPair>[];
  void take(int? i, int? j, String method, [double score = 1]) {
    if ((i != null && !ra.contains(i)) || (j != null && !rb.contains(j)))
      throw const FormatException(
          'Ánh xạ sheet phải một–một và trỏ tới sheet tồn tại.');
    if (i != null) ra.remove(i);
    if (j != null) rb.remove(j);
    pairs.add(SheetPair(i, j, i == null ? null : a[i].name,
        j == null ? null : b[j].name, method, score));
  }

  for (final (na, nb) in overrides) {
    final i = na == null ? null : a.indexWhere((s) => s.name == na),
        j = nb == null ? null : b.indexWhere((s) => s.name == nb);
    if ((i == null && j == null) || i == -1 || j == -1)
      throw const FormatException('Không tìm thấy sheet trong ánh xạ đã chọn.');
    take(i, j, 'manual');
  }
  for (final normalize in <String Function(String)>[
    (s) => s,
    normalizeSheetLabel
  ]) {
    for (final i in ra.toList()) {
      if (isGenericSheetName(a[i].name)) continue;
      final label = normalize(a[i].name);
      final aa = ra
              .where((k) =>
                  !isGenericSheetName(a[k].name) &&
                  normalize(a[k].name) == label)
              .toList(),
          bb = rb
              .where((k) =>
                  !isGenericSheetName(b[k].name) &&
                  normalize(b[k].name) == label)
              .toList();
      if (aa.length == 1 && bb.length == 1) take(i, bb.single, 'name');
    }
  }
  final candidates = [
    for (final i in ra)
      for (final j in rb) (i: i, j: j, score: sheetStructureScore(a[i], b[j]))
  ];
  for (final c in candidates) {
    if (c.score < .8) continue;
    double rival(bool sameA) => candidates
        .where(
            (x) => sameA ? x.i == c.i && x.j != c.j : x.j == c.j && x.i != c.i)
        .fold<double>(0, (m, x) => x.score > m ? x.score : m);
    if (c.score - rival(true) >= .08 && c.score - rival(false) >= .08)
      take(c.i, c.j, 'structure', c.score);
  }
  if (ra.isNotEmpty && rb.isNotEmpty)
    return SheetMappingPlan(pairs, ra.toList(), rb.toList());
  for (final i in ra.toList()) take(i, null, 'only-a');
  for (final j in rb.toList()) take(null, j, 'only-b');
  return SheetMappingPlan(pairs, const [], const []);
}
