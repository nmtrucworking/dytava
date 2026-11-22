/// Native port of web/js/compare-engine.js cell rules. Presentation diff is lazy.
import 'semantic_poc.dart';

final class WebComparisonPolicy {
  const WebComparisonPolicy(
      {this.trimText = true,
      this.caseSensitiveText = false,
      this.preserveLeadingZeros = true,
      this.caseSensitiveIdentifier = true,
      this.distinctNullZero = true,
      this.treatOrdinalAsMetadata = true});
  final bool trimText,
      caseSensitiveText,
      preserveLeadingZeros,
      caseSensitiveIdentifier,
      distinctNullZero,
      treatOrdinalAsMetadata;
}

final class WebCellEngine {
  const WebCellEngine([this.policy = const WebComparisonPolicy()]);
  final WebComparisonPolicy policy;
  static const _true = {'true', '1', 'yes', 'có', 'đúng', 'y', 't', 'active'};
  static const _false = {
    'false',
    '0',
    'no',
    'không',
    'sai',
    'n',
    'f',
    'inactive'
  };
  static bool isOrdinal(String header) =>
      RegExp(r'^(#|no\.?|stt|số thứ tự|ordinal|row_?num|index)$',
              caseSensitive: false)
          .hasMatch(header.trim());
  static bool _identifier(String s) =>
      RegExp(r'^0\d+$').hasMatch(s.trim()) ||
      RegExp(r'^[A-Za-z]{2,5}[-_]?\d+$').hasMatch(s.trim());
  static bool _blank(String s) =>
      {'', 'NULL', 'BLANK'}.contains(s.trim().toUpperCase());

  ComparisonDecision compare(SourceCell a, SourceCell b,
      {String? explicitType, double tolerance = 0}) {
    final content = compareCellContent(a, b);
    if (content != null) return content;
    final x = a.rawLexeme ?? '', y = b.rawLexeme ?? '';
    ComparisonDecision result(DecisionStatus status, String rule, String reason,
            [String? na, String? nb]) =>
        ComparisonDecision(
            status: status,
            ruleId: rule,
            explanation: reason,
            left: TextValue(na ?? x),
            right: TextValue(nb ?? y));
    ComparisonDecision equal(
            bool same, String rule, String reason, String na, String nb) =>
        result(same ? DecisionStatus.equivalent : DecisionStatus.different,
            rule, reason, na, nb);
    if ((a.kind == CellKind.ocrText && !a.ocrReviewed) ||
        (b.kind == CellKind.ocrText && !b.ocrReviewed)) {
      return result(DecisionStatus.unresolved, 'ocr/review_required',
          'Cần xác nhận dữ liệu OCR.');
    }
    if (x == y)
      return result(DecisionStatus.exact, 'exact/verbatim',
          'Giá trị tuyệt đối giống nhau.');
    if (x.trim().startsWith('=') && y.trim().startsWith('=')) {
      final fa = _canonicalFormula(x), fb = _canonicalFormula(y);
      if (fa == fb) {
        return result(
          DecisionStatus.equivalent,
          'formula/syntax_normalized',
          'Biểu thức công thức tương đương sau khi chuẩn hóa cú pháp (; ↔ , và hoa/thường).',
          fa,
          fb,
        );
      }
    }
    if (explicitType == 'identifier' ||
        (explicitType == null && (_identifier(x) || _identifier(y)))) {
      String norm(String s) {
        if (policy.trimText) s = s.trim();
        if (!policy.preserveLeadingZeros)
          s = s.replaceFirst(RegExp(r'^0+(?=\d)'), '');
        return policy.caseSensitiveIdentifier ? s : s.toLowerCase();
      }

      final na = norm(x), nb = norm(y);
      return equal(na == nb, 'identifier/policy',
          'So sánh mã định danh theo số 0 và hoa thường.', na, nb);
    }
    if (explicitType == 'text') {
      String norm(String s) {
        if (policy.trimText) s = s.trim();
        return policy.caseSensitiveText ? s : s.toLowerCase();
      }

      return equal(norm(x) == norm(y), 'text/policy',
          'So sánh văn bản theo chính sách.', norm(x), norm(y));
    }
    if (_blank(x) && _blank(y))
      return result(DecisionStatus.equivalent, 'null/equivalent',
          'Cả hai là ô trống.', '<BLANK>', '<BLANK>');
    if ((_blank(x) && y == '0') || (_blank(y) && x == '0'))
      return result(
          policy.distinctNullZero
              ? DecisionStatus.different
              : DecisionStatus.equivalent,
          policy.distinctNullZero
              ? 'null/distinct_zero'
              : 'null/zero_equivalent',
          'So sánh ô trống và số 0 theo chính sách.',
          policy.distinctNullZero ? (_blank(x) ? '<BLANK>' : x) : '0',
          policy.distinctNullZero ? (_blank(y) ? '<BLANK>' : y) : '0');
    double? percent(String s) => s.trim().endsWith('%')
        ? double.tryParse(
            s.trim().replaceFirst(RegExp(r'%$'), '').replaceAll(',', '.'))
        : null;
    final pa = percent(x), pb = percent(y);
    if (pa != null || pb != null) {
      final na =
          pa != null ? pa / 100 : double.tryParse(x.replaceAll(',', '.'));
      final nb =
          pb != null ? pb / 100 : double.tryParse(y.replaceAll(',', '.'));
      if (na != null && nb != null && na.isFinite && nb.isFinite)
        return equal(
            (na - nb).abs() <= 0.000001,
            (na - nb).abs() <= 0.000001
                ? 'percentage/scaling'
                : 'percentage/difference',
            'So sánh tỷ lệ sau chuẩn hóa.',
            _numericText(na),
            _numericText(nb));
    }
    bool? boolean(String s) => _true.contains(s.trim().toLowerCase())
        ? true
        : _false.contains(s.trim().toLowerCase())
            ? false
            : null;
    final ba = boolean(x), bb = boolean(y);
    if (ba != null && bb != null)
      return equal(
          ba == bb,
          ba == bb ? 'boolean/alias_mapping' : 'boolean/mismatch',
          'So sánh giá trị logic qua bí danh.',
          '$ba',
          '$bb');
    final datePattern = RegExp(r'^\d{1,4}[-/.]\d{1,2}[-/.]\d{1,4}');
    if (datePattern.hasMatch(x) || datePattern.hasMatch(y)) {
      if (RegExp(r'^\d{2}/\d{2}/\d{2}$').hasMatch(x) ||
          RegExp(r'^\d{2}/\d{2}/\d{2}$').hasMatch(y))
        return result(DecisionStatus.unresolved, 'date/ambiguous_locale',
            'Ngày tháng có năm hai chữ số cần xác nhận.');
      String? date(String s) {
        if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(s))
          return s.substring(0, 10);
        final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})').firstMatch(s);
        return m == null
            ? null
            : '${m[3]}-${m[2]!.padLeft(2, '0')}-${m[1]!.padLeft(2, '0')}';
      }

      final da = date(x), db = date(y);
      if (da != null && db != null)
        return equal(
            da == db,
            da == db ? 'date/iso_normalized' : 'date/mismatch',
            'So sánh ngày sau chuẩn hóa ISO.',
            da,
            db);
    }
    final na = _number(x), nb = _number(y);
    final issues = [na.$2, nb.$2];
    final issue = [
      'decimal/precision_limit',
      'decimal/ambiguous_fraction',
      'numeric/unknown_locale'
    ].where(issues.contains).firstOrNull;
    if (issue != null)
      return result(DecisionStatus.unresolved, issue,
          'Định dạng số mơ hồ hoặc vượt độ chính xác an toàn.');
    if (na.$1 != null && nb.$1 != null)
      return equal(
          (na.$1! - nb.$1!).abs() <= tolerance,
          (na.$1! - nb.$1!).abs() <= tolerance
              ? 'decimal/vi-VN_tolerance'
              : 'decimal/numeric_difference',
          'So sánh số sau chuẩn hóa, dung sai ±$tolerance.',
          _numericText(na.$1!),
          _numericText(nb.$1!));
    var sa = policy.trimText ? x.trim() : x,
        sb = policy.trimText ? y.trim() : y;
    final lexicalA = sa, lexicalB = sb;
    if (sa == sb)
      return result(DecisionStatus.equivalent, 'text/trim',
          'Tương đương sau khi bỏ khoảng trắng đầu/cuối.', sa, sb);
    if (policy.trimText) {
      sa = sa.replaceAll(RegExp(r'[\s\u00a0]+'), ' ');
      sb = sb.replaceAll(RegExp(r'[\s\u00a0]+'), ' ');
    }
    if (sa == sb)
      return result(DecisionStatus.equivalent, 'text/whitespace_normalized',
          'Tương đương sau chuẩn hóa khoảng trắng.', sa, sb);
    if (!policy.caseSensitiveText && sa.toLowerCase() == sb.toLowerCase())
      return result(
          DecisionStatus.equivalent,
          'text/case_fold',
          'Tương đương sau khi bỏ qua hoa/thường.',
          sa.toLowerCase(),
          sb.toLowerCase());
    return result(DecisionStatus.different, 'text/lexical_diff',
        'Nội dung chuỗi ký tự khác nhau.', lexicalA, lexicalB);
  }

  static String _numericText(double value) => value == value.truncateToDouble()
      ? value.toInt().toString()
      : value.toString();

  static String _canonicalFormula(String raw) {
    var body = raw.trim().substring(1).trim();
    body = body.replaceAll(
      RegExp(r'\b(?:_xlfn|_xlws)\.', caseSensitive: false),
      '',
    );
    final buf = StringBuffer('=');
    var inQuotes = false;
    for (var i = 0; i < body.length; i++) {
      final ch = body[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
        buf.write(ch);
      } else if (inQuotes) {
        buf.write(ch);
      } else if (ch == ';') {
        buf.write(',');
      } else if (ch.trim().isEmpty) {
        continue;
      } else {
        buf.write(ch.toUpperCase());
      }
    }
    return buf.toString();
  }

  static (double?, String?) _number(String value) {
    var s = value.trim();
    if (RegExp(r'^[+-]?[,.]\d+$').hasMatch(s)) {
      final normalized = s
          .replaceFirstMapped(
            RegExp(r'^([+-]?)([,.])'),
            (m) => '${m[1]}0.',
          );
      return (double.tryParse(normalized), null);
    }
    if (RegExp(r'^\d{1,2}/\d{1,2}$').hasMatch(s))
      return (null, 'decimal/ambiguous_fraction');
    if (RegExp(r'^\d{1,3}[,.]\d{3}$').hasMatch(s))
      return (null, 'numeric/unknown_locale');
    if (!RegExp(r'^[+-]?\d{1,3}([,.]\d{3})*([,.]\d+)?$').hasMatch(s) &&
        !RegExp(r'^[+-]?\d+([,.]\d+)?$').hasMatch(s)) return (null, null);
    if (RegExp(r'^\d{1,3}(,\d{3})+(\.\d+)?$').hasMatch(s)) {
      s = s.replaceAll(',', '');
    } else if (RegExp(r'^\d{1,3}(\.\d{3})+(,\d+)?$').hasMatch(s)) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else {
      s = s.replaceAll(',', '.');
    }
    if (s
            .replaceFirst(RegExp(r'^[+-]?0*'), '')
            .replaceAll(RegExp(r'[^0-9]'), '')
            .length >
        15) return (null, 'decimal/precision_limit');
    return (double.tryParse(s), null);
  }
}
