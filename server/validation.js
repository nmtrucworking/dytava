import { z } from 'zod';

export const credentialsSchema = z.object({ email: z.email().max(254).transform(s => s.toLowerCase()), password: z.string().min(12).max(128) }).strict();
export const registrationSchema = credentialsSchema.extend({ name: z.string().trim().min(2).max(80) });
export const policyConfigSchema = z.object({
  tolerance_abs: z.number().min(0).max(1e9),
  preserve_leading_zeros: z.boolean(),
  case_sensitive_identifier: z.boolean(),
  case_sensitive_text: z.boolean(),
  trim_text: z.boolean(),
  distinct_null_zero: z.boolean()
}).strict();
export const policySchema = z.object({
  id: z.string().regex(/^[a-z0-9][a-z0-9-]{2,79}$/),
  name: z.string().trim().min(2).max(100),
  description: z.string().trim().max(500),
  config: policyConfigSchema
}).strict();
export const httpsUrl = z.url().max(2048).refine(value => {
  const url = new URL(value);
  return url.protocol === 'https:' && !url.username && !url.password;
}, 'URL tải xuống phải dùng HTTPS, không chứa thông tin đăng nhập.');
export const releaseSchema = z.object({
  product: z.string().trim().min(2).max(100),
  platform: z.enum(['Android APK/AAB', 'Web WASM/Client JS', 'macOS / Linux Binary', 'Python Package (PyPI)']),
  version: z.string().regex(/^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$/).max(60),
  stage: z.enum(['Stable', 'Beta', 'Production']),
  size: z.string().trim().min(1).max(40),
  sha256: z.string().regex(/^[a-fA-F0-9]{64}$/).transform(s => s.toLowerCase()),
  downloadUrl: httpsUrl,
  changelog: z.string().trim().min(1).max(5000)
}).strict();
const count = z.number().int().min(0).max(1e8);
const format = z.enum(['csv', 'tsv', 'txt', 'json', 'xlsx']);
export const comparisonSchema = z.object({
  clientId: z.uuid(),
  formatA: format, formatB: format,
  rowsA: count, rowsB: count,
  durationMs: z.number().finite().min(0).max(86400000),
  policyId: z.string().min(1).max(100),
  policyConfig: policyConfigSchema,
  summary: z.object({ total_cells_checked: count, exact: count, equivalent: count, different: count, unresolved: count, added_rows: count, removed_rows: count }).strict()
}).strict().refine(v => v.summary.total_cells_checked === v.summary.exact + v.summary.equivalent + v.summary.different + v.summary.unresolved, 'Tổng số ô không khớp thống kê.').refine(v => v.summary.added_rows <= v.rowsB && v.summary.removed_rows <= v.rowsA, 'Số dòng thêm/xóa không hợp lệ.');
export const paginationSchema = z.object({ limit: z.coerce.number().int().min(1).max(100).default(25), offset: z.coerce.number().int().min(0).max(1000000).default(0) });
