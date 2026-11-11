/**
 * Dytava / ExcelCompare - Core Semantic Comparison & Alignment Engine
 * Compliant with EXC PRD 1.0-DESIGN
 */

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
    if (!this.policy.case_sensitive_text) {
      if (strA.toLowerCase() === strB.toLowerCase()) {
        return {
          status: "EQUIVALENT",
          type: "string",
          rawA, rawB,
          normA: strA.toLowerCase(),
          normB: strB.toLowerCase(),
          ruleId: "text/case_fold",
          reason: "Tương đương sau khi bỏ qua chữ hoa/thường (Case-fold equivalent)"
        };
      }
    }

    return {
      status: "DIFFERENT",
      type: "string",
      rawA, rawB,
      normA: strA, normB: strB,
      ruleId: "text/lexical_diff",
      reason: "Nội dung chuỗi ký tự khác nhau (Preserve accents & characters)"
    };
  }

  /**
   * Compare two datasets (tables) aligned by a Key Column or by Row Index
   */
  compareTables(fileA, fileB, keyColumn = null) {
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
    let pairs;
    if (keyColumn) {
      if (!indexA.has(keyColumn) || !indexB.has(keyColumn)) throw new Error('Cột khóa phải tồn tại trong cả hai tệp.');
      const makeMap = (rows, index, side) => {
        const map = new Map();
        for (const row of rows) {
          const key = String(row[index] ?? '').trim();
          if (!key || map.has(key)) throw new Error(`Nguồn ${side} có khóa trống hoặc trùng. Chọn cột khóa duy nhất hoặc căn chỉnh theo thứ tự dòng.`);
          map.set(key, row);
        }
        return map;
      };
      const a = makeMap(rowsA, indexA.get(keyColumn), 'A');
      const b = makeMap(rowsB, indexB.get(keyColumn), 'B');
      pairs = [...new Set([...a.keys(), ...b.keys()])].map(key => [key, a.get(key), b.get(key)]);
    } else {
      pairs = Array.from({ length: Math.max(rowsA.length, rowsB.length) }, (_, i) => [`Dòng ${i + 1}`, rowsA[i], rowsB[i]]);
    }
    for (const [key, rowA, rowB] of pairs) {
      const cellComparisons = Object.create(null);
      let rowStatus = 'EXACT';
      let type = 'MATCHED';
      if (!rowA || !rowB) {
        type = rowStatus = rowA ? 'REMOVED' : 'ADDED';
        summary[rowA ? 'removed_rows' : 'added_rows']++;
        differences.push({ kind: 'ROW', key, status: rowStatus, left: rowA || null, right: rowB || null });
      } else {
        for (const col of headers) {
          const a = rowA[indexA.get(col)] ?? '';
          const b = rowB[indexB.get(col)] ?? '';
          const cmp = !indexA.has(col) || !indexB.has(col) ? {
            status: 'DIFFERENT', type: 'schema', rawA: String(a), rawB: String(b), normA: String(a), normB: String(b),
            ruleId: 'schema/missing_column', reason: 'Cột chỉ tồn tại ở một nguồn dữ liệu.'
          } : this.compareCells(a, b, col);
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
      alignedRows.push({ type, key, rowStatus, rowA: rowA || null, rowB: rowB || null, cellComparisons });
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
