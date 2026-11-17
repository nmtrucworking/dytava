/// Presentation evidence only; never determines or changes a cell verdict.
/// Offsets count Unicode scalars in the supplied comparison text, not bytes,
/// UTF-16 code units, graphemes or source-file coordinates.
final class TextDifference {
  const TextDifference({
    required this.prefix,
    required this.partA,
    required this.partB,
    required this.suffix,
    required this.scalarOffset,
  });

  final String prefix;
  final String partA;
  final String partB;
  final String suffix;
  final int scalarOffset;
  int get position => scalarOffset + 1;

  /// One differing region after removing the shared prefix/suffix. This is
  /// deliberately not an edit-distance or minimal multi-region diff algorithm.
  static TextDifference? between(String a, String b) {
    if (a == b) return null;
    final left = a.runes.toList(growable: false);
    final right = b.runes.toList(growable: false);
    var prefix = 0;
    while (prefix < left.length &&
        prefix < right.length &&
        left[prefix] == right[prefix]) {
      prefix++;
    }
    var endA = left.length;
    var endB = right.length;
    while (endA > prefix &&
        endB > prefix &&
        left[endA - 1] == right[endB - 1]) {
      endA--;
      endB--;
    }
    return TextDifference(
      prefix: String.fromCharCodes(left.take(prefix)),
      partA: String.fromCharCodes(left.sublist(prefix, endA)),
      partB: String.fromCharCodes(right.sublist(prefix, endB)),
      suffix: String.fromCharCodes(left.skip(endA)),
      scalarOffset: prefix,
    );
  }

  String get description =>
      'Vị trí khác biệt đầu tiên: ký tự Unicode thứ $position. '
      'A: ${_describe(partA)}; B: ${_describe(partB)}.';

  static String _describe(String part) => switch (part) {
    '' => 'không có ký tự (∅)',
    ' ' => 'dấu cách (U+0020)',
    '\t' => 'tab (U+0009)',
    '\n' => 'xuống dòng (U+000A)',
    '\r' => 'về đầu dòng (U+000D)',
    '\u00a0' => 'dấu cách không ngắt (U+00A0)',
    _ =>
      part.runes.length == 1
          ? '“${visibleText(part)}” (U+${part.runes.single.toRadixString(16).toUpperCase().padLeft(4, '0')})'
          : '“${visibleText(part)}”',
  };

  static String visibleText(String text) => text
      .replaceAll(' ', '␠')
      .replaceAll('\t', '⇥')
      .replaceAll('\n', '↵')
      .replaceAll('\r', '␍')
      .replaceAll('\u00a0', '⍽');
}
