import express from 'express';
import helmet from 'helmet';
import { rateLimit } from 'express-rate-limit';
import { randomUUID, createHash } from 'node:crypto';
import { z, ZodError } from 'zod';
import { resolve } from 'node:path';
import { sessionMiddleware, createUser, publicUser, hashPassword, verifyPassword, setSession, clearSession, requireUser, requireAdmin } from './auth.js';
import { transaction } from './db.js';
import { credentialsSchema, registrationSchema, policySchema, releaseSchema, comparisonSchema, paginationSchema } from './validation.js';

const releaseRow = r => ({ id: r.id, product: r.product, platform: r.platform, version: r.version, stage: r.stage, size: r.size, sha256: r.sha256, downloadUrl: r.download_url, changelog: r.changelog, releaseDate: r.release_date });
const policyRow = r => ({ id: r.id, name: r.name, description: r.description, config: JSON.parse(r.config), revision: r.revision, updatedAt: r.updated_at });
const flagRow = r => ({ id: r.id, name: r.name, desc: r.description, enabled: Boolean(r.enabled), revision: r.revision, tier: 'Web' });
const comparisonRow = r => ({ id: r.id, clientId: r.client_id, formatA: r.format_a, formatB: r.format_b, rowsA: r.rows_a, rowsB: r.rows_b, durationMs: r.duration_ms, policyId: r.policy_id, policyConfig: JSON.parse(r.policy_config), summary: JSON.parse(r.summary), metadataSha256: r.metadata_sha256, createdAt: r.created_at });
const auditRow = r => ({ id: r.id, action: r.action, resourceId: r.resource_id, details: JSON.parse(r.details), createdAt: r.created_at });
const fail = (status, message) => { throw Object.assign(new Error(message), { status }); };

export async function createApp({ db, config }) {
  const app = express();
  app.disable('x-powered-by');
  app.set('trust proxy', config.trustProxy);
  app.use(helmet({ contentSecurityPolicy: { directives: {
    defaultSrc: ["'self'"], scriptSrc: ["'self'"], styleSrc: ["'self'", "'unsafe-inline'"],
    imgSrc: ["'self'", 'data:', 'blob:'], fontSrc: ["'self'"], connectSrc: ["'self'"],
    workerSrc: ["'self'"], objectSrc: ["'none'"], frameAncestors: ["'none'"],
    upgradeInsecureRequests: config.production ? [] : null
  } }, strictTransportSecurity: config.production ? undefined : false }));
  app.use((req, res, next) => {
    req.requestId = randomUUID();
    res.setHeader('X-Request-Id', req.requestId);
    next();
  });
  const api = express.Router();
  api.use((_req, res, next) => { res.setHeader('Cache-Control', 'no-store'); next(); });
  api.get('/health', (_req, res) => {
    db.prepare('SELECT 1').get();
    res.json({ status: 'ok', version: '1.0.0' });
  });
  api.use(rateLimit({ windowMs: 60_000, limit: 300, standardHeaders: 'draft-8', legacyHeaders: false, message: { error: 'Quá nhiều yêu cầu. Vui lòng thử lại sau.' } }));
  api.use((req, res, next) => {
    if (!['GET', 'HEAD', 'OPTIONS'].includes(req.method)) {
      // Cross-site forms cannot send this custom header. No cross-origin CORS is enabled.
      if (req.headers['x-dytava-request'] !== '1' || (req.headers.origin && req.headers.origin !== config.origin) || req.headers['sec-fetch-site'] === 'cross-site') {
        return res.status(403).json({ error: 'Yêu cầu phải xuất phát từ website Dytava.' });
      }
      if (!req.is('application/json')) return res.status(415).json({ error: 'Chỉ nhận application/json.' });
    }
    next();
  });
  api.use(express.json({ limit: '32kb', strict: true }));
  api.use(sessionMiddleware(db));
  const audit = (req, action, resourceId, details = {}) => db.prepare('INSERT INTO audit_logs(actor_id,action,resource_id,details) VALUES(?,?,?,?)').run(req.user?.id || null, action, resourceId, JSON.stringify(details));
  const flagEnabled = id => Boolean(db.prepare('SELECT enabled FROM feature_flags WHERE id=?').get(id)?.enabled);
  const dummyHash = await hashPassword(randomUUID());
  const authLimiter = rateLimit({ windowMs: 15 * 60_000, limit: 20, standardHeaders: 'draft-8', legacyHeaders: false, message: { error: 'Quá nhiều lần xác thực. Vui lòng thử lại sau 15 phút.' } });
  api.get('/auth/me', (req, res) => res.json({ user: req.user || null, allowRegistration: config.allowRegistration }));
  api.post('/auth/register', authLimiter, async (req, res) => {
    if (!config.allowRegistration) fail(403, 'Website đang tạm đóng đăng ký.');
    const values = registrationSchema.parse(req.body);
    const user = await createUser(db, values);
    setSession(db, req, res, user.id, config);
    res.status(201).json({ user });
  });
  api.post('/auth/login', authLimiter, async (req, res) => {
    const values = credentialsSchema.parse(req.body);
    const row = db.prepare('SELECT * FROM users WHERE email=?').get(values.email);
    const valid = await verifyPassword(values.password, row?.password_hash || dummyHash);
    if (!row || !valid) fail(401, 'Email hoặc mật khẩu không đúng.');
    setSession(db, req, res, row.id, config);
    res.json({ user: publicUser(row) });
  });
  api.post('/auth/logout', (req, res) => {
    if (req.sessionHash) db.prepare('DELETE FROM sessions WHERE token_hash=?').run(req.sessionHash);
    clearSession(res, config);
    res.status(204).end();
  });
  api.post('/auth/password', authLimiter, requireUser, async (req, res) => {
    const input = z.object({ currentPassword: z.string().max(128), newPassword: z.string().min(12).max(128) }).strict().parse(req.body);
    const row = db.prepare('SELECT * FROM users WHERE id=?').get(req.user.id);
    if (!await verifyPassword(input.currentPassword, row.password_hash)) fail(401, 'Mật khẩu hiện tại không đúng.');
    const hash = await hashPassword(input.newPassword);
    transaction(db, () => {
      db.prepare('UPDATE users SET password_hash=? WHERE id=?').run(hash, req.user.id);
      db.prepare('DELETE FROM sessions WHERE user_id=?').run(req.user.id);
      audit(req, 'account.password_changed', req.user.id);
    });
    setSession(db, req, res, req.user.id, config);
    res.status(204).end();
  });
  api.get('/config', (_req, res) => res.json({
    flags: db.prepare('SELECT * FROM feature_flags ORDER BY id').all().map(flagRow),
    policies: db.prepare('SELECT * FROM policies ORDER BY id').all().map(policyRow),
    retentionDays: config.retentionDays
  }));
  api.get('/releases', (_req, res) => res.json({ items: db.prepare('SELECT * FROM releases ORDER BY created_at DESC, id DESC LIMIT 100').all().map(releaseRow) }));

  api.get('/comparisons', requireUser, (req, res) => {
    const { limit, offset } = paginationSchema.parse(req.query);
    const items = db.prepare('SELECT * FROM comparisons WHERE user_id=? ORDER BY created_at DESC, id DESC LIMIT ? OFFSET ?').all(req.user.id, limit, offset).map(comparisonRow);
    const { total } = db.prepare('SELECT count(*) AS total FROM comparisons WHERE user_id=?').get(req.user.id);
    res.json({ items, total, limit, offset });
  });
  api.post('/comparisons', requireUser, (req, res) => {
    if (!flagEnabled('FLAG_HISTORY')) fail(403, 'Tính năng lưu thống kê đang tắt.');
    const input = comparisonSchema.parse(req.body);
    const hash = createHash('sha256').update(JSON.stringify(input)).digest('hex');
    const existing = db.prepare('SELECT * FROM comparisons WHERE user_id=? AND client_id=?').get(req.user.id, input.clientId);
    if (existing) {
      if (existing.metadata_sha256 !== hash) fail(409, 'Mã phiên đã được dùng cho thống kê khác.');
      return res.json({ item: comparisonRow(existing) });
    }
    const id = randomUUID();
    transaction(db, () => {
      db.prepare('INSERT INTO comparisons(id,user_id,client_id,format_a,format_b,rows_a,rows_b,duration_ms,policy_id,policy_config,summary,metadata_sha256) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)').run(id, req.user.id, input.clientId, input.formatA, input.formatB, input.rowsA, input.rowsB, input.durationMs, input.policyId, JSON.stringify(input.policyConfig), JSON.stringify(input.summary), hash);
      audit(req, 'comparison.saved', id);
    });
    res.status(201).json({ item: comparisonRow(db.prepare('SELECT * FROM comparisons WHERE id=?').get(id)) });
  });
  api.get('/comparisons/:id', requireUser, (req, res) => {
    const row = db.prepare('SELECT * FROM comparisons WHERE id=? AND user_id=?').get(req.params.id, req.user.id);
    if (!row) fail(404, 'Không tìm thấy phiên.');
    res.json({ item: comparisonRow(row) });
  });
  api.delete('/comparisons', requireUser, (req, res) => {
    transaction(db, () => {
      db.prepare('DELETE FROM comparisons WHERE user_id=?').run(req.user.id);
      audit(req, 'comparison.history_deleted', req.user.id);
    });
    res.status(204).end();
  });
  api.delete('/comparisons/:id', requireUser, (req, res) => {
    transaction(db, () => {
      const result = db.prepare('DELETE FROM comparisons WHERE id=? AND user_id=?').run(req.params.id, req.user.id);
      if (!result.changes) fail(404, 'Không tìm thấy phiên.');
      audit(req, 'comparison.deleted', req.params.id);
    });
    res.status(204).end();
  });

  api.use('/admin', requireAdmin);
  api.get('/admin/overview', (_req, res) => {
    const totals = db.prepare(`SELECT count(*) AS comparisons,
      coalesce(sum(json_extract(summary,'$.total_cells_checked')),0) AS cells,
      coalesce(sum(json_extract(summary,'$.equivalent')),0) AS equivalent,
      coalesce(sum(json_extract(summary,'$.unresolved')),0) AS unresolved,
      coalesce(avg(duration_ms),0) AS averageDurationMs FROM comparisons`).get();
    const formats = db.prepare('SELECT format, count(*) AS count FROM (SELECT format_a AS format FROM comparisons UNION ALL SELECT format_b FROM comparisons) GROUP BY format').all();
    res.json({ ...totals, users: db.prepare('SELECT count(*) AS n FROM users').get().n,
      releases: db.prepare('SELECT count(*) AS n FROM releases').get().n,
      formats, recent: db.prepare('SELECT * FROM comparisons ORDER BY created_at DESC LIMIT 5').all().map(comparisonRow),
      retentionDays: config.retentionDays, source: 'user-submitted-metadata'
    });
  });
  api.get('/admin/comparisons', (req, res) => {
    const { limit, offset } = paginationSchema.parse(req.query);
    res.json({ items: db.prepare('SELECT * FROM comparisons ORDER BY created_at DESC, id DESC LIMIT ? OFFSET ?').all(limit, offset).map(comparisonRow), total: db.prepare('SELECT count(*) AS n FROM comparisons').get().n, limit, offset });
  });
  api.get('/admin/audit', (req, res) => {
    const { limit, offset } = paginationSchema.parse(req.query);
    res.json({ items: db.prepare('SELECT * FROM audit_logs ORDER BY id DESC LIMIT ? OFFSET ?').all(limit, offset).map(auditRow), total: db.prepare('SELECT count(*) AS n FROM audit_logs').get().n, limit, offset });
  });
  api.get('/admin/audit/export', (_req, res) => {
    res.setHeader('Content-Disposition', 'attachment; filename="dytava-audit.json"');
    const rows = db.prepare('SELECT * FROM audit_logs ORDER BY id DESC LIMIT 10000').all();
    res.json({ items: rows.map(auditRow), total: db.prepare('SELECT count(*) AS n FROM audit_logs').get().n, limit: 10000 });
  });
  api.post('/admin/releases', (req, res) => {
    const value = releaseSchema.parse(req.body);
    const id = randomUUID();
    transaction(db, () => {
      db.prepare('INSERT INTO releases(id,product,platform,version,stage,size,sha256,download_url,changelog,release_date) VALUES(?,?,?,?,?,?,?,?,?,?)').run(id, value.product, value.platform, value.version, value.stage, value.size, value.sha256, value.downloadUrl, value.changelog, new Date().toISOString().slice(0, 10));
      audit(req, 'release.created', id);
    });
    res.status(201).json({ item: releaseRow(db.prepare('SELECT * FROM releases WHERE id=?').get(id)) });
  });
  api.put('/admin/releases/:id', (req, res) => {
    const value = releaseSchema.parse(req.body);
    transaction(db, () => {
      const result = db.prepare('UPDATE releases SET product=?,platform=?,version=?,stage=?,size=?,sha256=?,download_url=?,changelog=? WHERE id=?').run(value.product, value.platform, value.version, value.stage, value.size, value.sha256, value.downloadUrl, value.changelog, req.params.id);
      if (!result.changes) fail(404, 'Không tìm thấy bản phát hành.');
      audit(req, 'release.updated', req.params.id);
    });
    res.json({ item: releaseRow(db.prepare('SELECT * FROM releases WHERE id=?').get(req.params.id)) });
  });
  api.delete('/admin/releases/:id', (req, res) => {
    transaction(db, () => {
      if (!db.prepare('DELETE FROM releases WHERE id=?').run(req.params.id).changes) fail(404, 'Không tìm thấy bản phát hành.');
      audit(req, 'release.deleted', req.params.id);
    });
    res.status(204).end();
  });
  api.post('/admin/policies', (req, res) => {
    const value = policySchema.parse(req.body);
    transaction(db, () => {
      db.prepare('INSERT INTO policies(id,name,description,config) VALUES(?,?,?,?)').run(value.id, value.name, value.description, JSON.stringify(value.config));
      audit(req, 'policy.created', value.id);
    });
    res.status(201).json({ item: policyRow(db.prepare('SELECT * FROM policies WHERE id=?').get(value.id)) });
  });
  api.put('/admin/policies/:id', (req, res) => {
    const value = policySchema.extend({ revision: z.number().int().positive() }).parse(req.body);
    if (value.id !== req.params.id) fail(400, 'Không được đổi mã policy.');
    transaction(db, () => {
      const result = db.prepare("UPDATE policies SET name=?,description=?,config=?,revision=revision+1,updated_at=strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE id=? AND revision=?").run(value.name, value.description, JSON.stringify(value.config), value.id, value.revision);
      if (!result.changes) fail(409, 'Policy đã thay đổi hoặc đã xóa. Vui lòng tải lại.');
      audit(req, 'policy.updated', value.id, { revision: value.revision + 1 });
    });
    res.json({ item: policyRow(db.prepare('SELECT * FROM policies WHERE id=?').get(value.id)) });
  });
  api.delete('/admin/policies/:id', (req, res) => {
    transaction(db, () => {
      if (!db.prepare('DELETE FROM policies WHERE id=?').run(req.params.id).changes) fail(404, 'Không tìm thấy policy.');
      audit(req, 'policy.deleted', req.params.id);
    });
    res.status(204).end();
  });
  api.patch('/admin/flags/:id', (req, res) => {
    const value = z.object({ enabled: z.boolean(), revision: z.number().int().positive() }).strict().parse(req.body);
    transaction(db, () => {
      const result = db.prepare('UPDATE feature_flags SET enabled=?,revision=revision+1 WHERE id=? AND revision=?').run(Number(value.enabled), req.params.id, value.revision);
      if (!result.changes) fail(409, 'Cờ đã thay đổi hoặc không tồn tại. Vui lòng tải lại.');
      audit(req, 'flag.updated', req.params.id, { enabled: value.enabled, revision: value.revision + 1 });
    });
    res.json({ item: flagRow(db.prepare('SELECT * FROM feature_flags WHERE id=?').get(req.params.id)) });
  });
  api.use((_req, res) => res.status(404).json({ error: 'API không tồn tại.' }));
  app.use('/api', api);
  // Only the built frontend is public. Server sources, DB and .env never enter dist.
  app.use(express.static(config.staticDir, { dotfiles: 'deny', index: 'index.html', maxAge: config.production ? '1h' : 0, setHeaders(res, file) {
    if (file.endsWith('.html')) res.setHeader('Cache-Control', 'no-cache');
  } }));
  app.get('/', (_req, res) => res.sendFile(resolve(config.staticDir, 'index.html')));
  app.use((_req, res) => res.status(404).type('text').send('404 — Không tìm thấy tài nguyên.'));
  app.use((error, req, res, _next) => {
    if (error instanceof ZodError) return res.status(400).json({ error: 'Dữ liệu không hợp lệ.', fields: error.issues.map(i => ({ path: i.path.join('.'), message: i.message })) });
    if (error.code === 'SQLITE_CONSTRAINT_UNIQUE' || error.errcode === 2067 || /UNIQUE constraint failed/.test(error.message)) return res.status(409).json({ error: 'Email, mã hoặc phiên bản đã tồn tại.' });
    if (error.type === 'entity.too.large') return res.status(413).json({ error: 'Yêu cầu vượt quá 32 KB.' });
    if (error.type === 'entity.parse.failed') return res.status(400).json({ error: 'JSON không hợp lệ.' });
    const status = error.status && error.status < 500 ? error.status : 500;
    if (status === 500) console.error(JSON.stringify({ level: 'error', requestId: req.requestId, code: error.code || 'INTERNAL_ERROR' }));
    res.status(status).json({ error: status === 500 ? 'Lỗi máy chủ. Vui lòng thử lại.' : error.message, requestId: req.requestId });
  });
  return app;
}
