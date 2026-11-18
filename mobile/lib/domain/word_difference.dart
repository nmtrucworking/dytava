import 'dart:typed_data';

final class WordDiffToken {
  const WordDiffToken(this.text, this.changed);
  final String text;
  final bool changed;
}

/// Web LCS word highlighting, computed only for the inspected cell.
final class WordDifference {
  const WordDifference(this.a, this.b, this.similarity);
  final List<WordDiffToken> a, b;

  /// Null means edit-distance budget exceeded, never an invented similarity.
  final int? similarity;
  static WordDifference between(String a, String b) {
    List<String> tokenize(String s) {
      final tokens = <String>[];
      var offset = 0;
      for (final m in RegExp(r'(\s+|[.,;:\-–—/()]+)').allMatches(s)) {
        if (m.start > offset) tokens.add(s.substring(offset, m.start));
        tokens.add(m[0]!);
        offset = m.end;
      }
      if (offset < s.length) tokens.add(s.substring(offset));
      return tokens;
    }

    final x = tokenize(a), y = tokenize(b);
    if (x.length * y.length > 250000) {
      return WordDifference(
        [WordDiffToken(a, true)],
        [WordDiffToken(b, true)],
        _similarity(a, b),
      );
    }
    final dp = List.generate(x.length + 1, (_) => Int32List(y.length + 1));
    for (var i = 1; i <= x.length; i++) {
      for (var j = 1; j <= y.length; j++) {
        dp[i][j] = x[i - 1] == y[j - 1]
            ? dp[i - 1][j - 1] + 1
            : (dp[i - 1][j] > dp[i][j - 1] ? dp[i - 1][j] : dp[i][j - 1]);
      }
    }
    var i = x.length, j = y.length;
    final left = <WordDiffToken>[], right = <WordDiffToken>[];
    while (i > 0 || j > 0) {
      if (i > 0 && j > 0 && x[i - 1] == y[j - 1]) {
        left.add(WordDiffToken(x[--i], false));
        right.add(WordDiffToken(y[--j], false));
      } else if (j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j])) {
        right.add(WordDiffToken(y[--j], true));
      } else {
        left.add(WordDiffToken(x[--i], true));
      }
    }
    return WordDifference(
      left.reversed.toList(),
      right.reversed.toList(),
      _similarity(a, b),
    );
  }

  static int? _similarity(String a, String b) {
    if (a == b) return 100;
    final x = a.runes.toList(), y = b.runes.toList();
    if (x.isEmpty || y.isEmpty) return 0;
    if (x.length * y.length > 1000000) return null;
    var prev = List.generate(y.length + 1, (i) => i),
        curr = List.filled(y.length + 1, 0);
    for (var i = 1; i <= x.length; i++) {
      curr[0] = i;
      for (var j = 1; j <= y.length; j++) {
        final sub = prev[j - 1] + (x[i - 1] == y[j - 1] ? 0 : 1),
            del = prev[j] + 1,
            ins = curr[j - 1] + 1;
        curr[j] = sub < del ? (sub < ins ? sub : ins) : (del < ins ? del : ins);
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return ((1 - prev.last / (x.length > y.length ? x.length : y.length)) * 100)
        .round();
  }
}
