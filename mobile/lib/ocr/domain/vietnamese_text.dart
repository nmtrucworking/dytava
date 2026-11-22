import 'latin_nfc_tables.g.dart';

/// Unicode canonical normalization (NFC) for Latin script text, including all
/// Vietnamese letters, plus Vietnamese-specific OCR quality checks.
///
/// Only canonical equivalence is applied: `"e\u0302\u0301"`, `"ê\u0301"` and
/// `"ế"` become the same string. Compatibility forms, case and spacing are not
/// changed, so the visible content is never rewritten.
abstract final class VietnameseText {
  /// Returns the NFC form for Latin/Vietnamese characters. Code points outside
  /// the generated Latin tables pass through unchanged.
  static String nfc(String input) {
    if (input.isEmpty || !_needsWork(input)) return input;
    final decomposed = <int>[];
    for (final rune in input.runes) {
      _decompose(rune, decomposed);
    }
    _canonicalOrder(decomposed);
    return String.fromCharCodes(_compose(decomposed));
  }

  /// True when [input] contains a Vietnamese-specific letter or tone mark.
  static bool hasVietnameseMarks(String input) {
    for (final rune in nfc(input).runes) {
      if (_vietnameseLetters.contains(rune)) return true;
    }
    return false;
  }

  /// Signals that the recognized diacritics should be checked by a person.
  ///
  /// - a combining mark is left over after NFC (it could not attach to a letter);
  /// - two tone marks were stacked on one syllable;
  /// - a tone mark sits on a consonant.
  static bool hasDiacriticAnomaly(String input) {
    final composed = nfc(input);
    for (final rune in composed.runes) {
      if (_isCombining(rune)) return true;
    }
    // Stacked or misplaced tone marks are visible in the decomposed form.
    final decomposed = <int>[];
    for (final rune in composed.runes) {
      _decompose(rune, decomposed);
    }
    var tonesInCluster = 0;
    int? base;
    for (final rune in decomposed) {
      if (_isCombining(rune)) {
        if (_toneMarks.contains(rune)) {
          tonesInCluster++;
          if (tonesInCluster > 1) return true;
          if (base != null && !_vowelBases.contains(base)) return true;
        }
      } else {
        tonesInCluster = 0;
        base = rune;
      }
    }
    return false;
  }

  /// True when the text has at least one Latin letter.
  static bool hasLetter(String input) => input.runes.any(_isLetter);

  static bool _needsWork(String s) {
    for (final unit in s.codeUnits) {
      if (unit >= 0x00C0) return true;
    }
    return false;
  }

  static void _decompose(int rune, List<int> out) {
    final parts = latinCanonicalDecomposition[rune];
    if (parts == null) {
      out.add(rune);
      return;
    }
    for (final p in parts) {
      _decompose(p, out);
    }
  }

  static int _ccc(int rune) => latinCombiningClass[rune] ?? 0;

  static bool _isCombining(int rune) =>
      (rune >= 0x0300 && rune <= 0x036F) || _ccc(rune) != 0;

  static bool _isLetter(int rune) =>
      (rune >= 0x41 && rune <= 0x5A) ||
      (rune >= 0x61 && rune <= 0x7A) ||
      (rune >= 0x00C0 && rune <= 0x024F && rune != 0x00D7 && rune != 0x00F7) ||
      (rune >= 0x1E00 && rune <= 0x1EFF);

  /// Stable sort of each run of non-starters by combining class (UAX #15).
  static void _canonicalOrder(List<int> runes) {
    var i = 0;
    while (i < runes.length) {
      if (_ccc(runes[i]) == 0) {
        i++;
        continue;
      }
      final start = i;
      while (i < runes.length && _ccc(runes[i]) != 0) {
        i++;
      }
      final run = runes.sublist(start, i);
      final indexed = [for (var k = 0; k < run.length; k++) (k, run[k])];
      indexed.sort((a, b) {
        final c = _ccc(a.$2).compareTo(_ccc(b.$2));
        return c != 0 ? c : a.$1.compareTo(b.$1);
      });
      for (var k = 0; k < indexed.length; k++) {
        runes[start + k] = indexed[k].$2;
      }
    }
  }

  /// Canonical composition with the UAX #15 blocking rule.
  static List<int> _compose(List<int> runes) {
    final out = <int>[];
    var starterIndex = -1;
    var lastClass = -1;
    for (final rune in runes) {
      final cc = _ccc(rune);
      if (starterIndex >= 0) {
        final blocked = lastClass != -1 && (lastClass == 0 || lastClass >= cc);
        final composite = blocked
            ? null
            : latinPrimaryComposite[(out[starterIndex] << 21) | rune];
        if (composite != null && cc != 0) {
          out[starterIndex] = composite;
          continue;
        }
      }
      if (cc == 0) {
        starterIndex = out.length;
        lastClass = -1;
      } else {
        lastClass = cc;
      }
      out.add(rune);
    }
    return out;
  }

  // Grave, acute, tilde, hook above, dot below.
  static const _toneMarks = {0x0300, 0x0301, 0x0303, 0x0309, 0x0323};

  static final _vowelBases = {
    for (final c in 'aeiouyAEIOUY'.runes) c,
  };

  static final _vietnameseLetters = () {
    const letters =
        'àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ';
    final all = '$letters${letters.toUpperCase()}';
    return {for (final r in all.runes) r};
  }();
}
