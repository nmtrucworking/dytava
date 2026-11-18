/**
 * Dytava / ExcelCompare - Core Semantic Comparison & Alignment Engine
 * Compliant with EXC PRD 1.0-DESIGN
 */

export const EXACT_CMP = Object.freeze({
  status: 'EXACT',
  type: 'text',
  rawA: '',
  rawB: '',
  normA: '',
  normB: '',
  ruleId: 'exact/verbatim',
  reason: 'Giá trị tuyệt đối giống nhau (Exact identical value)'
});

export class CompareEngine {
  constructor(policy = {}) {
    this.policy = {
      policy_id: policy.policy_id || "default-policy-v1",
      decimal_separator: policy.decimal_separator || ",",
      allow_alternate_separator: policy.allow_alternate_separator ?? true,
      tolerance_abs: parseFloat(policy.tolerance_abs ?? 0),
      ignore_scale: policy.ignore_scale ?? true,
      preserve_leading_zeros: policy.preserve_leading_zeros ?? true,
      case_sensitive_identifier: policy.case_sensitive_identifier ?? true,
      case_sensitive_text: policy.case_sensitive_text ?? false,
      trim_text: policy.trim_text ?? true,
      distinct_null_zero: policy.distinct_null_zero ?? true,
      boolean_aliases: policy.boolean_aliases || {
        true: ["true", "1", "yes", "có", "đúng", "y", "t", "active"],
        false: ["false", "0", "no", "không", "sai", "n", "f", "inactive"]
      },
      date_format: policy.date_format || "AUTO",
      ...policy
    };
  }

  /**
   * Parse CSV, TSV, or TXT content into headers and rows
   */
  static parseDelimited(text, delimiter = null) {
    if (!text || typeof text !== "string") return { headers: [], rows: [] };
    const lines = text.replace(/\r\n/g, "\n").replace(/\r/g, "\n").split("\n").filter(l => l.trim().length > 0);
    if (lines.length === 0) return { headers: [], rows: [] };

    // Auto-detect delimiter if not given
    if (!delimiter) {
      const firstLine = lines[0];
      const commas = (firstLine.match(/,/g) || []).length;
      const tabs = (firstLine.match(/\t/g) || []).length;
      const semicolons = (firstLine.match(/;/g) || []).length;
      if (tabs >= commas && tabs >= semicolons && tabs > 0) delimiter = "\t";
      else if (semicolons > commas && semicolons > 0) delimiter = ";";
      else delimiter = ",";
    }

    const parseLine = (line) => {
      const result = [];
      let current = "";
      let inQuotes = false;
      for (let i = 0; i < line.length; i++) {
        const char = line[i];
        if (char === '"' || char === "'") {
          if (inQuotes && line[i + 1] === char) {
            current += char;
            i++;
          } else {
            inQuotes = !inQuotes;
          }
        } else if (char === delimiter && !inQuotes) {
          result.push(current.trim());
          current = "";
        } else {
          current += char;
        }
      }
      result.push(current.trim());
      return result;
    };

    const headers = parseLine(lines[0]);
    const rows = lines.slice(1).map(parseLine);
    return { headers, rows };
  }

  /**
   * Infer semantic data type of a cell value
   */
  inferSemanticType(val) {
    if (val === null || val === undefined || String(val).trim() === "" || String(val).toUpperCase() === "NULL" || String(val).toUpperCase() === "BLANK") {
      return "null";
    }
    const str = String(val).trim();

    // Check Boolean
    const lower = str.toLowerCase();
    if (this.policy.boolean_aliases.true.includes(lower) || this.policy.boolean_aliases.false.includes(lower)) {
      return "boolean";
    }

    // Check Percentage: e.g. "10%", "5.5%"
    if (/^[+-]?\d+([.,]\d+)?\s*%$/.test(str)) {
      return "percentage";
    }

    // Check Identifier: starts with leading zeros (e.g. "00123") or code pattern like "SV001", "TXN-101"
    if (/^0\d+$/.test(str)) {
      return "identifier";
    }
    if (/^[A-Za-z]{2,5}[-_]?\d+$/.test(str)) {
      return "identifier";
    }

    // Check Decimal / Numeric: allow comma or dot
    const cleanNum = str.replace(/\s+/g, "").replace(/\./g, "").replace(/,/g, ".");
    if (!isNaN(cleanNum) && cleanNum !== "") {
      return "decimal";
    }

    // Check Date (ISO or DD/MM/YYYY)
    if (/^\d{4}-\d{2}-\d{2}/.test(str) || /^\d{1,2}\/\d{1,2}\/\d{2,4}/.test(str)) {
      return "datetime";
    }

    return "string";
  }

  /**
   * Normalize and compare two individual cell values
   */
  compareCells(valA, valB, fieldName = "", explicitType = null) {
    const rawA = valA === undefined || valA === null ? "" : String(valA);
    const rawB = valB === undefined || valB === null ? "" : String(valB);

    // Exact string identity
    if (rawA === rawB) {
      return {
        status: "EXACT",
        type: explicitType || this.inferSemanticType(rawA),
        rawA,
        rawB,
        normA: rawA,
        normB: rawB,
        ruleId: "exact/verbatim",
        reason: "Giá trị tuyệt đối giống nhau (Exact identical value)"
      };
    }

    if (explicitType === 'identifier' || (!explicitType && [rawA, rawB].some(value => this.inferSemanticType(value) === 'identifier'))) {
      let a = this.policy.trim_text ? rawA.trim() : rawA;
      let b = this.policy.trim_text ? rawB.trim() : rawB;
      if (!this.policy.preserve_leading_zeros) { a = a.replace(/^0+(?=\d)/, ''); b = b.replace(/^0+(?=\d)/, ''); }
      if (!this.policy.case_sensitive_identifier) { a = a.toLowerCase(); b = b.toLowerCase(); }
      return { status: a === b ? 'EQUIVALENT' : 'DIFFERENT', type: 'identifier', rawA, rawB, normA: a, normB: b,
        ruleId: 'identifier/policy', reason: 'So sánh mã định danh theo cấu hình số 0 và hoa thường.' };
    }
    if (explicitType === 'text' || explicitType === 'string') {
      let a = this.policy.trim_text ? rawA.trim() : rawA;
      let b = this.policy.trim_text ? rawB.trim() : rawB;
      if (!this.policy.case_sensitive_text) { a = a.toLowerCase(); b = b.toLowerCase(); }
      return { status: a === b ? 'EQUIVALENT' : 'DIFFERENT', type: 'string', rawA, rawB, normA: a, normB: b,
        ruleId: 'text/policy', reason: 'So sánh văn bản, giữ nguyên dấu tiếng Việt.' };
    }
    const typeA = explicitType || this.inferSemanticType(rawA);
    const typeB = explicitType || this.inferSemanticType(rawB);

    // Null vs Blank vs Zero checking
    const isNullOrBlankA = rawA.trim() === "" || rawA.toUpperCase() === "BLANK" || rawA.toUpperCase() === "NULL";
    const isNullOrBlankB = rawB.trim() === "" || rawB.toUpperCase() === "BLANK" || rawB.toUpperCase() === "NULL";

    if (isNullOrBlankA && isNullOrBlankB) {
      return {
        status: "EQUIVALENT",
        type: "null",
        rawA, rawB,
        normA: "<BLANK>", normB: "<BLANK>",
        ruleId: "null/equivalent",
        reason: "Cả hai đều là ô trống (Both cells are blank/null)"
      };
    }

    if (!this.policy.distinct_null_zero && ((isNullOrBlankA && rawB === '0') || (isNullOrBlankB && rawA === '0'))) {
      return { status: 'EQUIVALENT', type: 'null', rawA, rawB, normA: '0', normB: '0', ruleId: 'null/zero_equivalent', reason: 'Policy cho phép ô trống tương đương số 0.' };
    }
    if (this.policy.distinct_null_zero) {
      if ((isNullOrBlankA && rawB === "0") || (isNullOrBlankB && rawA === "0")) {
        return {
          status: "DIFFERENT",
          type: "numeric",
          rawA, rawB,
          normA: isNullOrBlankA ? "<BLANK>" : rawA,
          normB: isNullOrBlankB ? "<BLANK>" : rawB,
          ruleId: "null/distinct_zero",
          reason: "Phân biệt rõ giữa ô trống (BLANK) và số 0 (Zero)"
        };
      }
    }

    // Percentage Normalization: e.g. "0.1" vs "10%"
    const parsePercent = (val) => {
      const s = String(val).trim();
      if (s.endsWith("%")) {
        const num = parseFloat(s.slice(0, -1).replace(",", "."));
        return isNaN(num) ? null : num / 100;
      }
      return null;
    };

    const pctA = parsePercent(rawA);
    const pctB = parsePercent(rawB);
    if (pctA !== null || pctB !== null) {
      const numA = pctA !== null ? pctA : parseFloat(rawA.replace(",", "."));
      const numB = pctB !== null ? pctB : parseFloat(rawB.replace(",", "."));
      if (!isNaN(numA) && !isNaN(numB)) {
        if (Math.abs(numA - numB) <= 0.000001) {
          return {
            status: "EQUIVALENT",
            type: "percentage",
            rawA, rawB,
            normA: numA.toString(),
            normB: numB.toString(),
            ruleId: "percentage/scaling",
            reason: "Tương đương giá trị phần trăm (Percentage scale normalized)"
          };
        } else {
          return {
            status: "DIFFERENT",
            type: "percentage",
            rawA, rawB,
            normA: numA.toString(),
            normB: numB.toString(),
            ruleId: "percentage/difference",
            reason: "Giá trị tỷ lệ phần trăm chênh lệch"
          };
        }
      }
    }

    // Boolean comparison
    const normBool = (val) => {
      const s = String(val).trim().toLowerCase();
      if (this.policy.boolean_aliases.true.includes(s)) return true;
      if (this.policy.boolean_aliases.false.includes(s)) return false;
      return null;
    };

    const bA = normBool(rawA);
    const bB = normBool(rawB);
    if (bA !== null && bB !== null) {
      if (bA === bB) {
        return {
          status: "EQUIVALENT",
          type: "boolean",
          rawA, rawB,
          normA: String(bA),
          normB: String(bB),
          ruleId: "boolean/alias_mapping",
          reason: `Khớp giá trị logic qua từ điển bí danh ('${rawA}' ≡ '${rawB}')`
        };
      } else {
        return {
          status: "DIFFERENT",
          type: "boolean",
          rawA, rawB,
          normA: String(bA),
          normB: String(bB),
          ruleId: "boolean/mismatch",
          reason: "Giá trị logic đối lập (True vs False)"
        };
      }
    }

    // Identifier comparison: Leading zeros & casing (only for numeric-like identifiers or explicit identifier types)
    const isNumericIdA = /^0\d+$/.test(rawA);
    const isNumericIdB = /^0\d+$/.test(rawB);

    if (this.policy.preserve_leading_zeros && (isNumericIdA || isNumericIdB || explicitType === "identifier")) {
      if (rawA !== rawB) {
        return {
          status: "DIFFERENT",
          type: "identifier",
          rawA, rawB,
          normA: rawA,
          normB: rawB,
          ruleId: "identifier/leading_zeros",
          reason: "Mã định danh khác biệt do bảo toàn số 0 đứng trước (Leading zeros preserved)"
        };
      }
    }

    if (typeA === "identifier" || typeB === "identifier") {
      if (this.policy.case_sensitive_identifier && rawA !== rawB) {
        return {
          status: "DIFFERENT",
          type: "identifier",
          rawA, rawB,
          normA: rawA,
          normB: rawB,
          ruleId: "identifier/case_sensitive",
          reason: "Mã định danh phân biệt chữ hoa chữ thường (Case-sensitive)"
        };
      }
    }

    // Datetime comparison (Check before numeric if type is date or date-like)
    const isDatePatternA = /^\d{1,4}[-/.]\d{1,2}[-/.]\d{1,4}/.test(rawA);
    const isDatePatternB = /^\d{1,4}[-/.]\d{1,2}[-/.]\d{1,4}/.test(rawB);

    if (explicitType === "date" || explicitType === "datetime" || isDatePatternA || isDatePatternB) {
      // Check 2-digit ambiguous years e.g. "01/02/26" vs "2026-02-01"
      if (/^\d{2}\/\d{2}\/\d{2}$/.test(rawA) || /^\d{2}\/\d{2}\/\d{2}$/.test(rawB)) {
        return {
          status: "UNRESOLVED",
          type: "date",
          rawA, rawB,
          normA: rawA, normB: rawB,
          ruleId: "date/ambiguous_locale",
          reason: "Ngày tháng 2 chữ số năm ('01/02/26') mơ hồ giữa DD/MM và MM/DD. Cần review."
        };
      }

      const parseDateStandard = (dStr) => {
        if (/^\d{4}-\d{2}-\d{2}/.test(dStr)) return dStr.slice(0, 10);
        const match = dStr.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})/);
        if (match) {
          const [, d, m, y] = match;
          return `${y}-${m.padStart(2, "0")}-${d.padStart(2, "0")}`;
        }
        return null;
      };

      const dateA = parseDateStandard(rawA);
      const dateB = parseDateStandard(rawB);
      if (dateA && dateB) {
        if (dateA === dateB) {
          return {
            status: "EQUIVALENT",
            type: "datetime",
            rawA, rawB,
            normA: dateA, normB: dateB,
            ruleId: "date/iso_normalized",
            reason: `Tương đương thời gian sau chuẩn hóa chuẩn ISO: ${dateA}`
          };
        } else {
          return {
            status: "DIFFERENT",
            type: "datetime",
            rawA, rawB,
            normA: dateA, normB: dateB,
            ruleId: "date/mismatch",
            reason: `Mốc thời gian khác biệt (${dateA} vs ${dateB})`
          };
        }
      }
    }

    // Numeric & Decimal Comparison
    const parseFlexibleDecimal = (val) => {
      let s = String(val).trim();
      // Ambiguous fraction or date check e.g. "07/10" or "1,234" vs "1.234"
      if (/^\d{1,2}\/\d{1,2}$/.test(s)) {
        return { ambiguous: true, val: s };
      }
      if (/^\d{1,3}[,.]\d{3}$/.test(s)) {
        // Can be thousand separator or decimal
        return { ambiguousLocale: true, val: s };
      }

      // Check if it actually looks like a number (not text with embedded numbers)
      if (!/^[+-]?\d{1,3}([,.]\d{3})*([,.]\d+)?$/.test(s) && !/^[+-]?\d+([,.]\d+)?$/.test(s)) {
        return { val: null, isNum: false };
      }

      // Handle thousand separators: "150,000,000" or "150.000.000"
      if (/^\d{1,3}(,\d{3})+(\.\d+)?$/.test(s)) {
        s = s.replace(/,/g, "");
      } else if (/^\d{1,3}(\.\d{3})+(,\d+)?$/.test(s)) {
        s = s.replace(/\./g, "").replace(",", ".");
      } else {
        // Simple decimal replacement if comma used
        s = s.replace(",", ".");
      }
      const significant = s.replace(/^[+-]?0*/, '').replace(/[^0-9]/g, '');
      if (significant.length > 15) return { unsafe: true };
      const n = parseFloat(s);
      return { val: isNaN(n) ? null : n, isNum: !isNaN(n) };
    };

    const parsedA = parseFlexibleDecimal(rawA);
    const parsedB = parseFlexibleDecimal(rawB);

    if (parsedA.unsafe || parsedB.unsafe) return { status: 'UNRESOLVED', type: 'decimal', rawA, rawB, normA: rawA, normB: rawB, ruleId: 'decimal/precision_limit', reason: 'Số vượt giới hạn độ chính xác an toàn, cần kiểm tra thủ công.' };
    if (parsedA.ambiguous || parsedB.ambiguous) {
      return {
        status: "UNRESOLVED",
        type: "ambiguous",
        rawA, rawB,
        normA: rawA, normB: rawB,
        ruleId: "decimal/ambiguous_fraction",
        reason: "Không thể tự suy luận định dạng điểm/tỷ lệ ('07/10'). Cần người dùng xác minh."
      };
    }

    if ((parsedA.ambiguousLocale || parsedB.ambiguousLocale) && rawA !== rawB) {
      return {
        status: "UNRESOLVED",
        type: "numeric",
        rawA, rawB,
        normA: rawA, normB: rawB,
        ruleId: "numeric/unknown_locale",
        reason: "Xung đột chuẩn phân cách hàng nghìn/thập phân ('1,234' vs '1.234'). Locale chưa rõ ràng."
      };
    }

    if (parsedA.isNum && parsedB.isNum) {
      const diff = Math.abs(parsedA.val - parsedB.val);
      const tol = this.policy.tolerance_abs;
      if (diff <= tol) {
        return {
          status: "EQUIVALENT",
          type: "decimal",
          rawA, rawB,
          normA: parsedA.val.toString(),
          normB: parsedB.val.toString(),
          ruleId: "decimal/vi-VN_tolerance",
          reason: `Giá trị tương đương sau khi chuẩn hóa phân cách và scale (Dung sai: ±${tol})`
        };
      } else {
        return {
          status: "DIFFERENT",
          type: "decimal",
          rawA, rawB,
          normA: parsedA.val.toString(),
          normB: parsedB.val.toString(),
          ruleId: "decimal/numeric_difference",
          reason: `Giá trị số chênh lệch: ${parsedA.val} so với ${parsedB.val}`
        };
      }
    }



    // Default String / Text comparison
    let strA = this.policy.trim_text ? rawA.trim() : rawA;
    let strB = this.policy.trim_text ? rawB.trim() : rawB;

    if (strA === strB) return { status: 'EQUIVALENT', type: 'string', rawA, rawB, normA: strA, normB: strB, ruleId: 'text/trim', reason: 'Tương đương sau khi loại bỏ khoảng trắng.' };

    if (this.policy.trim_text) {
      const normSpaceA = strA.replace(/[\s\u00A0]+/g, ' ');
      const normSpaceB = strB.replace(/[\s\u00A0]+/g, ' ');
      if (normSpaceA === normSpaceB) {
        return {
          status: 'EQUIVALENT',
          type: 'string',
          rawA, rawB,
          normA: normSpaceA,
          normB: normSpaceB,
          ruleId: 'text/whitespace_normalized',
          reason: 'Tương đương sau khi chuẩn hóa khoảng trắng thừa (Whitespace normalized).'
        };
      }
    }

    if (!this.policy.case_sensitive_text) {
      const normCaseA = (this.policy.trim_text ? strA.replace(/[\s\u00A0]+/g, ' ') : strA).toLowerCase();
      const normCaseB = (this.policy.trim_text ? strB.replace(/[\s\u00A0]+/g, ' ') : strB).toLowerCase();
      if (normCaseA === normCaseB) {
        return {
          status: "EQUIVALENT",
          type: "string",
          rawA, rawB,
          normA: normCaseA,
          normB: normCaseB,
          ruleId: "text/case_fold",
          reason: "Tương đương sau khi bỏ qua chữ hoa/thường (Case-fold equivalent)"
        };
      }
    }

    const wordDiff = this.computeWordDiff(rawA, rawB);
    const maxLen = Math.max(strA.length, strB.length);
    const levDist = this.levenshteinDistance(strA, strB);
    const similarity = maxLen > 0 ? Math.round((1 - levDist / maxLen) * 100) : 100;

    let diffReason = 'Nội dung chuỗi ký tự khác nhau';
    if (wordDiff.changedA.length && wordDiff.changedB.length) {
      diffReason = `Khác biệt từ: '${wordDiff.changedA.slice(0, 3).join(', ')}' ↔ '${wordDiff.changedB.slice(0, 3).join(', ')}' (Độ tương đồng ${similarity}%)`;
    } else if (similarity >= 80) {
      diffReason = `Chuỗi tương đồng cao (${similarity}%), khác một số ký tự`;
    }

    return {
      status: "DIFFERENT",
      type: "string",
      rawA, rawB,
      normA: strA, normB: strB,
      ruleId: "text/lexical_diff",
      reason: diffReason,
      similarity,
      diffHtmlA: wordDiff.htmlA,
      diffHtmlB: wordDiff.htmlB
    };
  }

  /**
   * Escape HTML entities
   */
  escapeHtml(str) {
    return String(str ?? '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  /**
   * Bounded Levenshtein distance for strings
   */
  levenshteinDistance(s1, s2) {
    if (s1 === s2) return 0;
    const len1 = s1.length;
    const len2 = s2.length;
    if (!len1) return len2;
    if (!len2) return len1;
    if (len1 > 1000 || len2 > 1000) return Math.abs(len1 - len2);

    let prev = new Int32Array(len2 + 1);
    let curr = new Int32Array(len2 + 1);
    for (let j = 0; j <= len2; j++) prev[j] = j;

    for (let i = 1; i <= len1; i++) {
      curr[0] = i;
      const c1 = s1.charCodeAt(i - 1);
      for (let j = 1; j <= len2; j++) {
        const cost = c1 === s2.charCodeAt(j - 1) ? 0 : 1;
        curr[j] = Math.min(prev[j] + 1, curr[j - 1] + 1, prev[j - 1] + cost);
      }
      const tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[len2];
  }

  /**
   * Compute token/word-level diff with HTML markups
   */
  computeWordDiff(strA, strB) {
    const rawA = String(strA ?? '');
    const rawB = String(strB ?? '');
    if (rawA === rawB) {
      const esc = this.escapeHtml(rawA);
      return { htmlA: esc, htmlB: esc, changedA: [], changedB: [] };
    }

    const tokenize = s => s.split(/(\s+|[.,;:\-–—/()]+)/).filter(Boolean);
    const tokensA = tokenize(rawA);
    const tokensB = tokenize(rawB);

    const m = tokensA.length;
    const n = tokensB.length;
    if (m * n > 250000) {
      return {
        htmlA: `<mark class="diff-word-del">${this.escapeHtml(rawA)}</mark>`,
        htmlB: `<mark class="diff-word-ins">${this.escapeHtml(rawB)}</mark>`,
        changedA: [rawA],
        changedB: [rawB]
      };
    }

    const dp = Array.from({ length: m + 1 }, () => new Int32Array(n + 1));
    for (let i = 1; i <= m; i++) {
      for (let j = 1; j <= n; j++) {
        dp[i][j] = tokensA[i - 1] === tokensB[j - 1]
          ? dp[i - 1][j - 1] + 1
          : Math.max(dp[i - 1][j], dp[i][j - 1]);
      }
    }

    let i = m, j = n;
    const chunksA = [], chunksB = [];
    while (i > 0 || j > 0) {
      if (i > 0 && j > 0 && tokensA[i - 1] === tokensB[j - 1]) {
        const t = tokensA[i - 1];
        chunksA.unshift({ text: t, type: 'equal' });
        chunksB.unshift({ text: t, type: 'equal' });
        i--; j--;
      } else if (j > 0 && (i === 0 || dp[i][j - 1] >= dp[i - 1][j])) {
        chunksB.unshift({ text: tokensB[j - 1], type: 'ins' });
        j--;
      } else if (i > 0 && (j === 0 || dp[i][j - 1] < dp[i - 1][j])) {
        chunksA.unshift({ text: tokensA[i - 1], type: 'del' });
        i--;
      }
    }

    const render = chunks => chunks.map(c => {
      const esc = this.escapeHtml(c.text);
      if (c.type === 'del') return `<mark class="diff-word-del">${esc}</mark>`;
      if (c.type === 'ins') return `<mark class="diff-word-ins">${esc}</mark>`;
      return esc;
    }).join('');

    const changedA = chunksA.filter(c => c.type === 'del').map(c => c.text.trim()).filter(Boolean);
    const changedB = chunksB.filter(c => c.type === 'ins').map(c => c.text.trim()).filter(Boolean);

    return {
      htmlA: render(chunksA),
      htmlB: render(chunksB),
      changedA,
      changedB
    };
  }

  /**
   * Check if a column header is an ordinal / sequence number metadata column
   */
  isOrdinalHeader(header) {
    return /^(#|no\.?|stt|số thứ tự|ordinal|row_?num|index)$/i.test(String(header || '').trim());
  }

  /**
   * Detect ordinal columns in datasets
   */
  detectOrdinalColumns(headers, rows) {
    const ordinalCols = new Set();
    for (let c = 0; c < headers.length; c++) {
      const h = headers[c];
      if (this.isOrdinalHeader(h)) {
        const sample = rows.slice(0, 25).map(r => String(r[c] ?? '').trim()).filter(Boolean);
        const isNumeric = sample.length > 0 && sample.every(v => v === '-' || !isNaN(Number(v)));
        if (isNumeric) ordinalCols.add(h);
      }
    }
    return ordinalCols;
  }

  /**
   * Sequence Alignment (Anchored LCS / Needleman-Wunsch with Gap Penalty)
   * Prevents off-by-one cascade errors when rows are inserted or removed in the middle.
   */
  alignBySequence(rowsA, rowsB, headersA, headersB, ordinalCols, options = {}) {
    const indexA = new Map(headersA.map((h, i) => [h, i]));
    const indexB = new Map(headersB.map((h, i) => [h, i]));
    const commonHeaders = headersA.filter(h => headersB.includes(h));
    const bizHeaders = commonHeaders.filter(h => !ordinalCols.has(h));
    const activeHeaders = bizHeaders.length > 0 ? bizHeaders : commonHeaders;

    const getSig = (row, idxMap) => {
      return activeHeaders.map(h => String(row[idxMap.get(h)] ?? '').trim()).join('|||');
    };

    const isBlankRow = (row, idxMap) => {
      return activeHeaders.every(h => {
        const v = String(row[idxMap.get(h)] ?? '').trim();
        return v === '' || v === '-';
      });
    };

    // Calculate row similarity between 0.0 and 1.0
    const calcRowSimilarity = (rA, rB) => {
      const blankA = isBlankRow(rA, indexA);
      const blankB = isBlankRow(rB, indexB);
      if (blankA && blankB) return 1.0;
      if (blankA || blankB) return 0.0;

      let matchCount = 0;
      for (const h of activeHeaders) {
        const valA = String(rA[indexA.get(h)] ?? '').trim();
        const valB = String(rB[indexB.get(h)] ?? '').trim();
        if (valA === valB) {
          matchCount += 1.0;
        } else if (valA.toLowerCase() === valB.toLowerCase()) {
          matchCount += 0.9;
        } else if (!isNaN(Number(valA)) && !isNaN(Number(valB)) && Number(valA) === Number(valB)) {
          matchCount += 1.0;
        }
      }
      return matchCount / activeHeaders.length;
    };

    // Phase 1: Identify Unique Monotonic Exact Anchors
    const mapA = new Map();
    rowsA.forEach((r, i) => {
      if (isBlankRow(r, indexA)) return;
      const sig = getSig(r, indexA);
      if (!mapA.has(sig)) mapA.set(sig, []);
      mapA.get(sig).push(i);
    });

    const mapB = new Map();
    rowsB.forEach((r, j) => {
      if (isBlankRow(r, indexB)) return;
      const sig = getSig(r, indexB);
      if (!mapB.has(sig)) mapB.set(sig, []);
      mapB.get(sig).push(j);
    });

    const candidateAnchors = [];
    for (const [sig, listA] of mapA.entries()) {
      if (listA.length === 1 && mapB.has(sig) && mapB.get(sig).length === 1) {
        candidateAnchors.push({ i: listA[0], j: mapB.get(sig)[0] });
      }
    }
    candidateAnchors.sort((a, b) => a.i - b.i);

    // Compute Longest Increasing Subsequence on j to preserve monotonic order
    const lis = [];
    const parent = new Array(candidateAnchors.length).fill(-1);
    const lisIndices = [];

    for (let k = 0; k < candidateAnchors.length; k++) {
      const jVal = candidateAnchors[k].j;
      let low = 0, high = lis.length - 1, pos = lis.length;
      while (low <= high) {
        const mid = (low + high) >> 1;
        if (candidateAnchors[lisIndices[mid]].j >= jVal) {
          pos = mid;
          high = mid - 1;
        } else {
          low = mid + 1;
        }
      }
      lisIndices[pos] = k;
      if (pos > 0) parent[k] = lisIndices[pos - 1];
      if (pos === lis.length) lis.push(k);
    }

    const anchors = [];
    let curr = lis.length > 0 ? lisIndices[lis.length - 1] : undefined;
    while (curr !== undefined && curr !== -1) {
      anchors.push(candidateAnchors[curr]);
      curr = parent[curr];
    }
    anchors.reverse();

    // Phase 2: Align segments between anchors
    const alignedPairs = [];

    const alignSegment = (startA, endA, startB, endB) => {
      const lenA = endA - startA + 1;
      const lenB = endB - startB + 1;
      if (lenA <= 0 && lenB <= 0) return;
      if (lenA <= 0) {
        for (let j = startB; j <= endB; j++) {
          alignedPairs.push({ rowA: null, rowB: rowsB[j], idxA: null, idxB: j, rationale: 'Dòng chèn mới ở Nguồn B' });
        }
        return;
      }
      if (lenB <= 0) {
        for (let i = startA; i <= endA; i++) {
          alignedPairs.push({ rowA: rowsA[i], rowB: null, idxA: i, idxB: null, rationale: 'Dòng bị xóa ở Nguồn A' });
        }
        return;
      }

      // If segment is very large, avoid massive O(M*N) allocation
      if (lenA * lenB > 4000000) {
        const maxLen = Math.max(lenA, lenB);
        for (let k = 0; k < maxLen; k++) {
          const rA = k < lenA ? rowsA[startA + k] : null;
          const rB = k < lenB ? rowsB[startB + k] : null;
          alignedPairs.push({ rowA: rA, rowB: rB, idxA: rA ? startA + k : null, idxB: rB ? startB + k : null, rationale: 'Căn chỉnh đoạn lớn theo vị trí' });
        }
        return;
      }

      // Needleman-Wunsch DP on bounded segment
      const dp = Array.from({ length: lenA + 1 }, () => new Float64Array(lenB + 1));
      for (let i = 0; i <= lenA; i++) dp[i][0] = i * 1.0;
      for (let j = 0; j <= lenB; j++) dp[0][j] = j * 1.0;

      for (let i = 1; i <= lenA; i++) {
        const rA = rowsA[startA + i - 1];
        for (let j = 1; j <= lenB; j++) {
          const rB = rowsB[startB + j - 1];
          const sim = calcRowSimilarity(rA, rB);
          // If sim >= 0.5, subCost in [0, 1] is cheaper than deletion + insertion (2.0)
          // If sim < 0.5, subCost is 2.5 (> 2.0), forcing insert/delete instead of false pairing
          const subCost = sim >= 0.5 ? 2.0 * (1.0 - sim) : 2.5;

          const costDiag = dp[i - 1][j - 1] + subCost;
          const costDel = dp[i - 1][j] + 1.0;
          const costIns = dp[i][j - 1] + 1.0;

          dp[i][j] = Math.min(costDiag, costDel, costIns);
        }
      }

      // Traceback
      let i = lenA, j = lenB;
      const segPairs = [];
      while (i > 0 || j > 0) {
        if (i > 0 && j > 0) {
          const rA = rowsA[startA + i - 1];
          const rB = rowsB[startB + j - 1];
          const sim = calcRowSimilarity(rA, rB);
          const subCost = sim >= 0.5 ? 2.0 * (1.0 - sim) : 2.5;
          const costDiag = dp[i - 1][j - 1] + subCost;
          const costDel = dp[i - 1][j] + 1.0;
          const costIns = dp[i][j - 1] + 1.0;

          if (Math.abs(dp[i][j] - costDiag) < 1e-6 && subCost < 2.0) {
            segPairs.push({
              rowA: rA, rowB: rB, idxA: startA + i - 1, idxB: startB + j - 1,
              rationale: sim === 1.0 ? 'Khớp toàn bộ nội dung' : `Khớp chuỗi tương đồng (${Math.round(sim * 100)}%)`
            });
            i--; j--;
            continue;
          }
          if (Math.abs(dp[i][j] - costDel) < 1e-6) {
            segPairs.push({ rowA: rA, rowB: null, idxA: startA + i - 1, idxB: null, rationale: 'Dòng bị xóa ở Nguồn A' });
            i--;
            continue;
          }
          segPairs.push({ rowA: null, rowB: rB, idxA: null, idxB: startB + j - 1, rationale: 'Dòng chèn mới ở Nguồn B' });
          j--;
        } else if (i > 0) {
          segPairs.push({ rowA: rowsA[startA + i - 1], rowB: null, idxA: startA + i - 1, idxB: null, rationale: 'Dòng bị xóa ở Nguồn A' });
          i--;
        } else {
          segPairs.push({ rowA: null, rowB: rowsB[startB + j - 1], idxA: null, idxB: startB + j - 1, rationale: 'Dòng chèn mới ở Nguồn B' });
          j--;
        }
      }
      segPairs.reverse();
      alignedPairs.push(...segPairs);
    };

    let prevA = 0, prevB = 0;
    for (const anchor of anchors) {
      alignSegment(prevA, anchor.i - 1, prevB, anchor.j - 1);
      alignedPairs.push({
        rowA: rowsA[anchor.i], rowB: rowsB[anchor.j],
        idxA: anchor.i, idxB: anchor.j,
        rationale: 'Mốc chuỗi chính xác (Anchor)'
      });
      prevA = anchor.i + 1;
      prevB = anchor.j + 1;
    }
    alignSegment(prevA, rowsA.length - 1, prevB, rowsB.length - 1);

    return alignedPairs;
  }

  /**
   * Compare two datasets (tables) aligned by a Key Column, Sequence Alignment, or Row Index
   */
  compareTables(fileA, fileB, keyColumn = null, options = {}) {
    if (typeof keyColumn === 'object' && keyColumn !== null) {
      options = keyColumn;
      keyColumn = options.keyColumn || null;
    }
    const headersA = fileA.headers || [];
    const headersB = fileB.headers || [];
    const rowsA = fileA.rows || [];
    const rowsB = fileB.rows || [];
    const headers = [...new Set([...headersA, ...headersB])];
    const indexA = new Map(headersA.map((h, i) => [h, i]));
    const indexB = new Map(headersB.map((h, i) => [h, i]));
    const summary = { total_cells_checked: 0, exact: 0, equivalent: 0, different: 0, unresolved: 0, added_rows: 0, removed_rows: 0 };
    const alignedRows = [];
    const differences = [];

    // Determine alignment mode
    let mode = options.alignmentMode || 'AUTO';
    if (keyColumn === '__ORDERED_SEQUENCE__') {
      mode = 'ORDERED_SEQUENCE';
      keyColumn = null;
    } else if (keyColumn === '__POSITIONAL__') {
      mode = 'POSITIONAL';
      keyColumn = null;
    } else if (keyColumn) {
      mode = 'KEY';
    } else if (mode === 'AUTO') {
      mode = 'POSITIONAL';
    }

    const ordinalCols = this.detectOrdinalColumns(headers, [...rowsA.slice(0, 50), ...rowsB.slice(0, 50)]);
    const treatOrdinalAsMetadata = options.treatOrdinalAsMetadata ?? this.policy.treat_ordinal_as_metadata ?? true;

    let pairs;
    if (mode === 'KEY') {
      if (!indexA.has(keyColumn) || !indexB.has(keyColumn)) throw new Error('Cột khóa phải tồn tại trong cả hai tệp.');
      const makeMap = (rows, index, side) => {
        const map = new Map();
        for (let i = 0; i < rows.length; i++) {
          const row = rows[i];
          const key = String(row[index] ?? '').trim();
          if (!key || map.has(key)) throw new Error(`Nguồn ${side} có khóa trống hoặc trùng. Chọn cột khóa duy nhất hoặc căn chỉnh theo thứ tự dòng.`);
          map.set(key, { row, idx: i });
        }
        return map;
      };
      const a = makeMap(rowsA, indexA.get(keyColumn), 'A');
      const b = makeMap(rowsB, indexB.get(keyColumn), 'B');
      pairs = [];
      const visited = new Set();
      for (const [key, itemA] of a) {
        visited.add(key);
        const itemB = b.get(key) || null;
        pairs.push({
          key,
          rowA: itemA.row,
          rowB: itemB ? itemB.row : null,
          sourceLineA: itemA.idx + 1,
          sourceLineB: itemB ? itemB.idx + 1 : null,
          rationale: itemB ? `Khóa định danh: ${key}` : 'Chỉ tồn tại ở Nguồn A'
        });
      }
      for (const [key, itemB] of b) {
        if (!visited.has(key)) {
          pairs.push({
            key,
            rowA: null,
            rowB: itemB.row,
            sourceLineA: null,
            sourceLineB: itemB.idx + 1,
            rationale: 'Chỉ tồn tại ở Nguồn B'
          });
        }
      }
    } else if (mode === 'ORDERED_SEQUENCE') {
      const seqPairs = this.alignBySequence(rowsA, rowsB, headersA, headersB, ordinalCols, options);
      pairs = seqPairs.map(p => {
        const lineA = p.idxA != null ? p.idxA + 1 : null;
        const lineB = p.idxB != null ? p.idxB + 1 : null;
        let keyStr;
        if (p.rowA && p.rowB) {
          keyStr = lineA === lineB ? `Dòng ${lineA}` : `A!${lineA} ↔ B!${lineB}`;
        } else if (p.rowA) {
          keyStr = `A!${lineA} (-Xóa)`;
        } else {
          keyStr = `B!${lineB} (+Thêm)`;
        }
        return {
          key: keyStr,
          rowA: p.rowA,
          rowB: p.rowB,
          sourceLineA: lineA,
          sourceLineB: lineB,
          rationale: p.rationale
        };
      });
    } else {
      // POSITIONAL
      pairs = Array.from({ length: Math.max(rowsA.length, rowsB.length) }, (_, i) => {
        const rowA = rowsA[i] || null;
        const rowB = rowsB[i] || null;
        return {
          key: `Dòng ${i + 1}`,
          rowA,
          rowB,
          sourceLineA: rowA ? i + 1 : null,
          sourceLineB: rowB ? i + 1 : null,
          rationale: 'So sánh theo thứ tự dòng (Positional)'
        };
      });
    }

    for (const pair of pairs) {
      const { key, rowA, rowB, sourceLineA, sourceLineB, rationale } = pair;
      const cellComparisons = Object.create(null);
      let rowStatus = 'EXACT';
      let type = 'MATCHED';
      if (!rowA || !rowB) {
        type = rowStatus = rowA ? 'REMOVED' : 'ADDED';
        summary[rowA ? 'removed_rows' : 'added_rows']++;
        differences.push({ kind: 'ROW', key, status: rowStatus, left: rowA || null, right: rowB || null, rationale });
      } else {
        for (const col of headers) {
          const a = rowA[indexA.get(col)] ?? '';
          const b = rowB[indexB.get(col)] ?? '';
          let cmp;
          if (!indexA.has(col) || !indexB.has(col)) {
            cmp = {
              status: 'DIFFERENT', type: 'schema', rawA: String(a), rawB: String(b), normA: String(a), normB: String(b),
              ruleId: 'schema/missing_column', reason: 'Cột chỉ tồn tại ở một nguồn dữ liệu.'
            };
          } else if (a === b) {
            cmp = EXACT_CMP;
          } else {
            cmp = this.compareCells(a, b, col);
          }

          // Downgrade ordinal column difference if row content matches
          if (ordinalCols.has(col) && treatOrdinalAsMetadata && cmp.status === 'DIFFERENT') {
            cmp = {
              status: 'EQUIVALENT',
              type: 'metadata',
              rawA: String(a),
              rawB: String(b),
              normA: String(a),
              normB: String(b),
              ruleId: 'metadata/ordinal_renumbered',
              reason: 'Số thứ tự dòng thay đổi do dịch chuyển vị trí (Metadata).'
            };
          }

          cellComparisons[col] = cmp;
          summary.total_cells_checked++;
          summary[cmp.status.toLowerCase()]++;
          const priority = { EXACT: 0, EQUIVALENT: 1, DIFFERENT: 2, UNRESOLVED: 3 };
          if (priority[cmp.status] > priority[rowStatus]) rowStatus = cmp.status;
          if (cmp.status === 'DIFFERENT' || cmp.status === 'UNRESOLVED') differences.push({
            kind: 'CELL', status: cmp.status, field: col, key,
            left: { raw: cmp.rawA, normalized: cmp.normA }, right: { raw: cmp.rawB, normalized: cmp.normB },
            ruleId: cmp.ruleId, reason: cmp.reason
          });
        }
      }
      alignedRows.push({
        type,
        key,
        rowStatus,
        rowA: rowA || null,
        rowB: rowB || null,
        sourceLineA,
        sourceLineB,
        matchRationale: rationale,
        cellComparisons
      });
    }

    const report = {
      schema_version: 1, report_id: `rep-${globalThis.crypto.randomUUID()}`, engine_version: '1.0.0-web',
      policy_id: this.policy.policy_id, policy: { ...this.policy }, key_column: keyColumn,
      inputs: { A: { name: fileA.name, format: fileA.format }, B: { name: fileB.name, format: fileB.format } },
      summary, differences, generated_at: new Date().toISOString()
    };
    return { headers, keyColumn, alignedRows, summary, report };
  }
}
