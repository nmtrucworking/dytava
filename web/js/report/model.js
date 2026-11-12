import { z } from 'zod';

export const REPORT_SCHEMA = 'dytava-report/1.0.0';
export const TEMPLATE_ID = 'dytava-comparison-report';
export const TEMPLATE_VERSION = '1.0.0';
export const STATUSES = ['EXACT', 'EQUIVALENT', 'DIFFERENT', 'UNRESOLVED'];
const text = z.string();
const count = z.number().int().nonnegative().safe();
const sha = z.string().regex(/^[a-f0-9]{64}$/);
const ref = z.object({ type: text, location: text }).strict();
const value = z.object({ raw_kind: z.enum(['TEXT', 'NUMBER', 'BOOLEAN', 'NULL', 'BLANK', 'EMPTY_STRING']).optional(), raw: z.union([text, z.number().finite(), z.boolean(), z.null()]), normalized: text.nullable().optional(), reference: ref.nullable().optional() }).strict();
const detail = z.object({ kind: z.enum(['CELL', 'ROW', 'FIELD']), status: z.enum([...STATUSES, 'ADDED', 'REMOVED']), field: text.optional(), key: z.union([text, z.array(text)]), left: value.nullable(), right: value.nullable(), rule_id: text.nullable().optional(), reason: text.nullable().optional() }).strict();
const source = z.object({ label: text, name: text.nullable(), format: text, sha256: sha.nullable(), size_bytes: count.nullable(), scope: text, parser_version: text.nullable() }).strict();
export const reportSchema = z.object({
  schema_version: z.literal(REPORT_SCHEMA), report_id: text.min(1), completion_state: z.literal('COMPLETED'), current: z.literal(true),
  ocr_review: z.enum(['NOT_REQUIRED', 'CONFIRMED']), generated_at: z.string().datetime({ offset: true }), engine_version: text.min(1),
  direction: z.enum(['A_TO_B', 'B_TO_A']), direction_confirmed: z.boolean(),
  inputs: z.object({ A: source, B: source }).strict(),
  policy_id: text, policy_digest: sha.nullable(), import_config_revision: text.nullable(), matching_mode: z.enum(['KEY', 'POSITIONAL']),
  key_fields: z.array(text), field_mapping: z.array(z.object({ left: text, right: text }).strict()),
  policy: z.record(text, z.union([text, z.number().finite(), z.boolean(), z.null()])),
  summary: z.object({ matched_cell_pairs: count, exact: count, equivalent: count, different: count, unresolved: count, added_rows: count, removed_rows: count, added_fields: count.optional(), removed_fields: count.optional(), rows_a: count.nullable(), rows_b: count.nullable(), fields_a: count.nullable(), fields_b: count.nullable() }).strict(),
  details_scope: z.enum(['FULL_COMPARISON', 'DIFFERENCES_ONLY', 'PROVIDED_DETAILS']),
  differences: z.array(detail), warnings: z.array(text), metadata_complete: z.boolean(),
}).strict();

// Compatibility is explicit. It does not invent hashes, source references or confirmations.
export function fromLegacyReport(report) {
  const source = (side) => ({ label: side, name: report.inputs?.[side]?.name ?? null, format: report.inputs?.[side]?.format ?? 'unknown', sha256: null, size_bytes: null, scope: 'Phạm vi do engine web cung cấp; chưa có scope manifest', parser_version: null });
  const warnings = [...(report.warnings || []), 'Metadata nguồn chưa đầy đủ: chưa có SHA-256, byte size, parser/config revision và xác nhận direction. Báo cáo này không xác nhận audit đầy đủ.'];
  return {
    schema_version: REPORT_SCHEMA, report_id: report.report_id, completion_state: report.completion_state ?? 'COMPLETED', current: report.current ?? true,
    ocr_review: report.ocr_review ?? 'NOT_REQUIRED', generated_at: report.generated_at, engine_version: report.engine_version,
    direction: report.direction ?? 'A_TO_B', direction_confirmed: false, inputs: { A: source('A'), B: source('B') },
    policy_id: report.policy_id ?? 'Không cung cấp', policy_digest: null, import_config_revision: null,
    matching_mode: report.key_column ? 'KEY' : 'POSITIONAL', key_fields: report.key_column ? [report.key_column] : [], field_mapping: [],
    policy: Object.fromEntries(Object.entries(report.policy || {}).filter(([, v]) => v === null || ['string', 'number', 'boolean'].includes(typeof v))),
    summary: { ...Object.fromEntries(['exact', 'equivalent', 'different', 'unresolved', 'added_rows', 'removed_rows'].map(k => [k, report.summary?.[k] ?? 0])), matched_cell_pairs: report.summary?.matched_cell_pairs ?? report.summary?.total_cells_checked, rows_a: null, rows_b: null, fields_a: null, fields_b: null },
    details_scope: 'PROVIDED_DETAILS',
    differences: (report.differences || []).map(d => ({ kind: d.kind, status: d.status, key: Array.isArray(d.key) ? d.key.map(String) : String(d.key), ...(d.field === undefined ? {} : { field: String(d.field) }),
      left: d.left === null ? null : { raw: Array.isArray(d.left) ? JSON.stringify(d.left) : d.left?.raw ?? null, normalized: d.left?.normalized == null ? null : String(d.left.normalized), reference: null },
      right: d.right === null ? null : { raw: Array.isArray(d.right) ? JSON.stringify(d.right) : d.right?.raw ?? null, normalized: d.right?.normalized == null ? null : String(d.right.normalized), reference: null },
      rule_id: d.rule_id ?? d.ruleId ?? null, reason: d.reason ?? null })), warnings, metadata_complete: false,
  };
}

export function validateReport(input, { allowLegacy = false, maxDetails = 2000, maxTextBytes = 2_000_000 } = {}) {
  // Bound this document renderer independently of the planned 1 GB input pipeline.
  const encoded = JSON.stringify(input);
  if (!encoded || new TextEncoder().encode(encoded).length > maxTextBytes) throw new Error('Report vượt budget renderer. Chọn phạm vi nhỏ hơn; không tự cắt nội dung.');
  const legacy = input.schema_version === 1;
  if (legacy && !allowLegacy) throw new Error('Report legacy cần allowLegacy rõ ràng; hãy cung cấp contract dytava-report/1.0.0.');
  const report = reportSchema.parse(legacy ? fromLegacyReport(input) : input);
  if (report.differences.length > maxDetails) throw new Error('Số detail vượt budget renderer; không xuất bản PDF thiếu dữ liệu.');
  const sum = STATUSES.reduce((n, status) => n + report.summary[status.toLowerCase()], 0);
  if (sum !== report.summary.matched_cell_pairs) throw new Error('Mẫu số matched_cell_pairs không khớp tổng bốn trạng thái.');
  if (report.inputs.A.label !== 'A' || report.inputs.B.label !== 'B') throw new Error('Nhãn source không khớp slot A/B.');
  for (const d of report.differences) {
    if (!legacy && d.kind === 'CELL' && (!d.field || !d.left?.reference || !d.right?.reference)) throw new Error('Cell report mới cần field và SourceRef hai phía.');
    if (!legacy && d.status === 'EQUIVALENT' && (!d.rule_id || d.left?.normalized == null || d.right?.normalized == null)) throw new Error('Equivalent cần rule và canonical trace hai phía.');
    if ((d.kind === 'CELL') !== STATUSES.includes(d.status)) throw new Error('Kind/status không tương thích.');
    if (d.kind === 'CELL' && (!d.left || !d.right)) throw new Error('Matched cell detail cần đủ hai phía.');
    if (d.kind !== 'CELL') {
      const presentRight = (d.status === 'ADDED') === (report.direction === 'A_TO_B');
      if ((presentRight ? d.right : d.left) === null || (presentRight ? d.left : d.right) !== null) throw new Error('Structural diff cần đúng một phía hiện diện theo direction.');
    }
  }
  for (const status of STATUSES) {
    const n = report.differences.filter(d => d.kind === 'CELL' && d.status === status).length;
    if (n > report.summary[status.toLowerCase()] || (report.details_scope === 'FULL_COMPARISON' && n !== report.summary[status.toLowerCase()])) throw new Error('Detail counts không khớp scope/summary.');
  }
  if (report.details_scope === 'DIFFERENCES_ONLY') {
    for (const status of ['DIFFERENT', 'UNRESOLVED']) if (report.differences.filter(d => d.kind === 'CELL' && d.status === status).length !== report.summary[status.toLowerCase()]) throw new Error('Differences-only phải giữ đủ different/unresolved.');
    if (report.differences.some(d => d.status === 'EXACT')) throw new Error('Differences-only không chứa exact.');
  }
  for (const [kind, status, name] of [['ROW', 'ADDED', 'added_rows'], ['ROW', 'REMOVED', 'removed_rows'], ['FIELD', 'ADDED', 'added_fields'], ['FIELD', 'REMOVED', 'removed_fields']]) {
    const actual = report.differences.filter(d => d.kind === kind && d.status === status).length;
    const total = report.summary[name];
    if (total !== undefined && (actual > total || (report.details_scope !== 'PROVIDED_DETAILS' && actual !== total))) throw new Error('Structural details không khớp scope/summary.');
  }
  if (!legacy && (!report.metadata_complete || !report.direction_confirmed || !report.policy_digest || !report.import_config_revision || !report.inputs.A.sha256 || !report.inputs.B.sha256 || report.inputs.A.size_bytes === null || report.inputs.B.size_bytes === null || !report.inputs.A.parser_version || !report.inputs.B.parser_version)) throw new Error('Report mới cần lineage, direction và metadata đầy đủ.');
  return report;
}
