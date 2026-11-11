/// EXCELCOMPARE Semantic Policy Engine — Dart-only educational PoC.
/// Implements selected types only: identifier, freeText, decimal, boolean, percentage.
/// It is not a file parser, row matcher, complete policy compiler, or production validator.
/// No Flutter imports or platform plugin dependencies.
import 'package:decimal/decimal.dart';

Decimal? _tryDecimal(String input) {
  try {
    return Decimal.parse(input);
  } on FormatException {
    return null;
  }
}

enum CellKind { text, number, boolean, missing, blank, jsonNull, ocrText, error }
enum SemanticType { identifier, freeText, decimal, boolean, percentage }
enum DecisionStatus { exact, equivalent, different, unresolved }

enum ReasonCode {
  parseFailed,
  localeAmbiguous,
  ocrReviewRequired,
  invalidPolicy,
  unsupportedSemanticType,
}

final class SourceCell {
  const SourceCell(this.kind, {this.rawLexeme, this.ocrReviewed = true});
  final CellKind kind;
  final String? rawLexeme;
  final bool ocrReviewed;
}

final class DecimalInputPolicy {
  const DecimalInputPolicy({required this.decimalSeparator,
    this.groupingSeparator, this.allowGrouping = false});
  final String decimalSeparator;
  final String? groupingSeparator;
  final bool allowGrouping;

  void validate() {
    if (decimalSeparator != '.' && decimalSeparator != ',') {
      throw const FormatException('Only explicit . or , decimal separator is supported in PoC');
    }
    if (allowGrouping) {
      throw const FormatException('Grouping parsing is not implemented in PoC; fail closed');
    }
    if (groupingSeparator == decimalSeparator) {
      throw const FormatException('Decimal/grouping separator conflict');
    }
  }
}

final class FieldPolicy {
  FieldPolicy({required this.field, required this.type,
    this.trim = false, this.aliases = const {},
    this.sourceA, this.sourceB, this.toleranceAbs = '0',
    this.percentSignIsScale = false}) {
    sourceA?.validate();
    sourceB?.validate();
    if (_tryDecimal(toleranceAbs) == null ||
        Decimal.parse(toleranceAbs).compareTo(Decimal.zero) < 0) {
      throw const FormatException('toleranceAbs must be a nonnegative exact decimal');
    }
    if (type == SemanticType.identifier && toleranceAbs != '0') {
      throw const FormatException('Identifiers never use tolerance');
    }
    if (type != SemanticType.decimal &&
        type != SemanticType.percentage && toleranceAbs != '0') {
      throw const FormatException('Tolerance supported for decimal/percentage only');
    }
  }

  final String field;
  final SemanticType type;
  final bool trim;
  final Map<String, bool> aliases;
  final DecimalInputPolicy? sourceA;
  final DecimalInputPolicy? sourceB;
  final String toleranceAbs;
  final bool percentSignIsScale;
}

sealed class CanonicalValue {
  const CanonicalValue();
  String get label;
}
final class TextValue extends CanonicalValue {
  const TextValue(this.value);
  final String value;
  @override String get label => value;
}
final class DecimalValue extends CanonicalValue {
  const DecimalValue(this.value, {this.percentage = false});
  final Decimal value;
  final bool percentage;
  @override String get label => value.toString();
}
final class BooleanValue extends CanonicalValue {
  const BooleanValue(this.value);
  final bool value;
  @override String get label => value.toString();
}
final class NullValue extends CanonicalValue {
  const NullValue(this.kind);
  final CellKind kind;
  @override String get label => kind.name;
}

final class NormalizedValue {
  const NormalizedValue(this.value, this.rules);
  final CanonicalValue value;
  final List<String> rules;
}
final class NormalizationOutcome {
  const NormalizationOutcome.success(this.value) : reason = null;
  const NormalizationOutcome.failure(this.reason) : value = null;
  final NormalizedValue? value;
  final ReasonCode? reason;
}

final class ComparisonDecision {
  const ComparisonDecision({required this.status, required this.ruleId,
    this.left, this.right, this.reason});
  final DecisionStatus status;
  final String ruleId;
  final CanonicalValue? left;
  final CanonicalValue? right;
  final ReasonCode? reason;
}

/// Strict, field-scoped parsing. Absence of an explicit text numeric profile
/// never falls back to `num.parse`, because `1,234` is locale ambiguous.
final class SemanticPolicyEngine {
  const SemanticPolicyEngine();

  ComparisonDecision compare(SourceCell a, SourceCell b, FieldPolicy policy) {
    final left = normalize(a, policy, side: 'A');
    final right = normalize(b, policy, side: 'B');
    final rule = 'semantic/${policy.type.name}/poc-v1';
    if (left.value == null || right.value == null) {
      return ComparisonDecision(status: DecisionStatus.unresolved,
        ruleId: rule, reason: left.reason ?? right.reason);
    }
    final x = left.value!.value;
    final y = right.value!.value;
    final semanticallyEqual = _equals(x, y, policy);
    if (semanticallyEqual && a.kind == b.kind && a.rawLexeme == b.rawLexeme) {
      return ComparisonDecision(status: DecisionStatus.exact,
        ruleId: rule, left: x, right: y);
    }
    return ComparisonDecision(status: semanticallyEqual
        ? DecisionStatus.equivalent : DecisionStatus.different,
      ruleId: rule, left: x, right: y);
  }

  NormalizationOutcome normalize(SourceCell cell, FieldPolicy policy, {required String side}) {
    if (cell.kind == CellKind.ocrText && !cell.ocrReviewed) {
      return const NormalizationOutcome.failure(ReasonCode.ocrReviewRequired);
    }
    if (cell.kind == CellKind.error) {
      return const NormalizationOutcome.failure(ReasonCode.parseFailed);
    }
    if (cell.kind == CellKind.blank || cell.kind == CellKind.missing ||
        cell.kind == CellKind.jsonNull) {
      return NormalizationOutcome.success(NormalizedValue(
          NullValue(cell.kind), const ['null/distinct/v1']));
    }
    var s = cell.rawLexeme;
    if (s == null) return const NormalizationOutcome.failure(ReasonCode.parseFailed);
    if (policy.trim) s = s.trim();

    switch (policy.type) {
      case SemanticType.identifier:
        // A numeric source loses string metadata (e.g. leading zeroes);
        // no implicit cast into identifier is allowed.
        if (cell.kind == CellKind.number) {
          return const NormalizationOutcome.failure(ReasonCode.parseFailed);
        }
        return NormalizationOutcome.success(NormalizedValue(TextValue(s),
            const ['identifier/preserve-lexeme/v1']));
      case SemanticType.freeText:
        // Unicode NFC normalization needs a separately verified implementation.
        // This PoC therefore deliberately uses code-point-preserving equality.
        return NormalizationOutcome.success(NormalizedValue(TextValue(s),
            const ['text/codepoint-preserving/v1']));
      case SemanticType.boolean:
        if (cell.kind == CellKind.boolean && (s == 'true' || s == 'false')) {
          return NormalizationOutcome.success(NormalizedValue(BooleanValue(s == 'true'),
              const ['boolean/native/v1']));
        }
        if (!policy.aliases.containsKey(s)) {
          return const NormalizationOutcome.failure(ReasonCode.parseFailed);
        }
        return NormalizationOutcome.success(NormalizedValue(BooleanValue(policy.aliases[s]!),
            const ['boolean/explicit-alias/v1']));
      case SemanticType.decimal:
      case SemanticType.percentage:
        final isPercentage = policy.type == SemanticType.percentage;
        final hadPercent = s.endsWith('%');
        if (hadPercent && (!isPercentage || !policy.percentSignIsScale)) {
          return const NormalizationOutcome.failure(ReasonCode.parseFailed);
        }
        if (hadPercent) s = s.substring(0, s.length - 1).trim();
        // Physical NUMBER values from a spreadsheet / JSON number lexical
        // notation use '.' irrespective of display locale.
        final parseProfile = cell.kind == CellKind.number
            ? const DecimalInputPolicy(decimalSeparator: '.')
            : (side == 'A' ? policy.sourceA : policy.sourceB);
        if (parseProfile == null) {
          return const NormalizationOutcome.failure(ReasonCode.localeAmbiguous);
        }
        final decimal = _parseDecimal(s, parseProfile);
        if (decimal == null) {
          return const NormalizationOutcome.failure(ReasonCode.parseFailed);
        }
        final result = hadPercent ? Decimal.parse(_shiftDecimalByTwo(decimal.toString())) : decimal;
        return NormalizationOutcome.success(NormalizedValue(
            DecimalValue(result, percentage: isPercentage),
            [hadPercent ? 'percentage/sign-scale/v1' : 'decimal/explicit-separator/v1']));
    }
  }

  Decimal? _parseDecimal(String s, DecimalInputPolicy profile) {
    // No grouping supported. Reject alternate separator instead of guessing.
    final sep = RegExp.escape(profile.decimalSeparator);
    if (!RegExp('^[+-]?[0-9]+($sep[0-9]+)?\$').hasMatch(s)) return null;
    final normalized = profile.decimalSeparator == ',' ? s.replaceAll(',', '.') : s;
    return _tryDecimal(normalized);
  }

  // Multiply an exact decimal by 10^-2 using decimal-point displacement,
  // never binary floating point. Examples: 10 -> 0.10, 12.5 -> 0.125.
  String _shiftDecimalByTwo(String input) {
    final sign = input.startsWith('-') ? '-' : '';
    final plain = input.startsWith('-') || input.startsWith('+') ? input.substring(1) : input;
    final segments = plain.split('.');
    final frac = segments.length == 2 ? segments[1].length : 0;
    final digits = segments.join('');
    final newFrac = frac + 2;
    final padded = digits.padLeft(newFrac + 1, '0');
    final pointIndex = padded.length - newFrac;
    return '$sign${padded.substring(0, pointIndex)}.${padded.substring(pointIndex)}';
  }

  bool _equals(CanonicalValue x, CanonicalValue y, FieldPolicy policy) {
    if (x is NullValue && y is NullValue) return x.kind == y.kind;
    if (x is TextValue && y is TextValue) return x.value == y.value;
    if (x is BooleanValue && y is BooleanValue) return x.value == y.value;
    if (x is DecimalValue && y is DecimalValue && x.percentage == y.percentage) {
      final delta = x.value - y.value;
      final absDelta = delta.compareTo(Decimal.zero) < 0 ? -delta : delta;
      return absDelta.compareTo(Decimal.parse(policy.toleranceAbs)) <= 0;
    }
    return false;
  }
}
