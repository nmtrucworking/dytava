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

  String get description => localizedDescription(true);

  String localizedDescription([bool isVietnamese = true]) => isVietnamese
      ? 'Vị trí khác biệt đầu tiên: ký tự Unicode thứ $position. '
          'A: ${_describe(partA, true)}; B: ${_describe(partB, true)}.'
      : 'First difference at Unicode character #$position. '
          'A: ${_describe(partA, false)}; B: ${_describe(partB, false)}.';

  static String _describe(String part, [bool isVietnamese = true]) => switch (part) {
    '' => isVietnamese ? 'không có ký tự (∅)' : 'no character (∅)',
    ' ' => isVietnamese ? 'dấu cách (U+0020)' : 'space (U+0020)',
    '\t' => 'tab (U+0009)',
    '\n' => isVietnamese ? 'xuống dòng (U+000A)' : 'newline (U+000A)',
    '\r' => isVietnamese ? 'về đầu dòng (U+000D)' : 'carriage return (U+000D)',
    '\u00a0' => isVietnamese ? 'dấu cách không ngắt (U+00A0)' : 'non-breaking space (U+00A0)',
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
