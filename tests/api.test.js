import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { once } from 'node:events';
import { randomUUID } from 'node:crypto';
import { createApp } from '../server/app.js';
import { openDatabase, pruneDatabase, transaction } from '../server/db.js';
import { createUser } from '../server/auth.js';
import { loadConfig } from '../server/config.js';

let db, server, base, adminCookie, userCookie, otherCookie, savedId;
const dir = mkdtempSync(join(tmpdir(), 'dytava-test-'));
const password = 'test-only-password-2026';
const config = { ...loadConfig({}), staticDir: resolve('dist'), origin: 'http://127.0.0.1', databasePath: join(dir, 'test.sqlite') };
const summary = { total_cells_checked: 4, exact: 1, equivalent: 1, different: 1, unresolved: 1, added_rows: 0, removed_rows: 0 };
const policyConfig = { tolerance_abs: 0, preserve_leading_zeros: true, case_sensitive_identifier: true, case_sensitive_text: false, trim_text: true, distinct_null_zero: true };
const metadata = { clientId: randomUUID(), formatA: 'csv', formatB: 'xlsx', rowsA: 2, rowsB: 2, durationMs: 42.5, policyId: 'web-custom-policy', policyConfig, summary };
const release = { product: 'Test Web', platform: 'Web WASM/Client JS', version: '1.0.0', stage: 'Production', size: '2 MB', sha256: 'a'.repeat(64), downloadUrl: 'https://example.com/dytava.zip', changelog: '<script>never execute</script>' };
async function request(path, { method = 'GET', body, cookie, headers = {} } = {}) {
  const response = await fetch(`${base}/api${path}`, { method, headers: { 'Content-Type': 'application/json', 'X-Dytava-Request': '1', Origin: config.origin, ...(cookie ? { Cookie: cookie } : {}), ...headers }, body: body === undefined ? undefined : JSON.stringify(body) });
  const data = response.status === 204 ? null : await response.json();
  return { response, data, cookie: response.headers.get('set-cookie')?.split(';')[0] };
}
before(async () => {
  db = openDatabase(config.databasePath);
  for (const [email, role] of [['admin@example.com', 'admin'], ['user@example.com', 'user'], ['other@example.com', 'user']]) await createUser(db, { email, role, name: role, password });
  const app = await createApp({ db, config }); server = app.listen(0, '127.0.0.1'); await once(server, 'listening');
  base = `http://127.0.0.1:${server.address().port}`; config.origin = base;
  adminCookie = (await request('/auth/login', { method: 'POST', body: { email: 'admin@example.com', password } })).cookie;
  userCookie = (await request('/auth/login', { method: 'POST', body: { email: 'user@example.com', password } })).cookie;
  otherCookie = (await request('/auth/login', { method: 'POST', body: { email: 'other@example.com', password } })).cookie;
});
after(async () => { await new Promise(resolve => { server.close(resolve); server.closeAllConnections(); }); db.close(); rmSync(dir, { recursive: true, force: true }); });

test('health and errors are JSON, sensitive source files are not served', async () => {
  assert.equal((await request('/health')).data.status, 'ok');
  assert.equal((await request('/does-not-exist')).response.status, 404);
  for (const path of ['/.env', '/server/app.js', '/server.js', '/data/dytava.sqlite', '/package.json', '/%ZZ']) {
    const res = await fetch(`${base}${path}`); assert.equal(res.status, 404, path);
  }
  const res = await fetch(base); assert.match(res.headers.get('content-security-policy'), /script-src 'self'/); assert.equal(res.headers.get('x-powered-by'), null);
});
test('signup hashes password, forces user role and stores opaque HttpOnly session', async () => {
  const payload = { name: 'New User', email: 'NEW@example.com', password };
  assert.equal((await request('/auth/register', { method: 'POST', body: { ...payload, role: 'admin' } })).response.status, 400);
  const result = await request('/auth/register', { method: 'POST', body: payload });
  assert.equal(result.response.status, 201); assert.equal(result.data.user.role, 'user');
  assert.equal(result.data.user.email, 'new@example.com'); assert.equal(result.data.user.password_hash, undefined);
  assert.match(result.response.headers.get('set-cookie'), /HttpOnly/); assert.match(result.response.headers.get('set-cookie'), /SameSite=Strict/);
  const row = db.prepare('SELECT * FROM users WHERE id=?').get(result.data.user.id); assert.notEqual(row.password_hash, password);
  assert.equal(db.prepare('SELECT count(*) n FROM sessions WHERE token_hash=?').get(result.cookie.split('=')[1]).n, 0);
  assert.equal((await request('/auth/register', { method: 'POST', body: payload })).response.status, 409);
});
test('rejects wrong login, validates body, and enforces CSRF boundary', async () => {
  assert.equal((await request('/auth/login', { method: 'POST', body: { email: 'user@example.com', password: 'wrong-password-long' } })).response.status, 401);
  assert.equal((await request('/auth/login', { method: 'POST', body: { email: 'missing@example.com', password } })).response.status, 401);
  assert.equal((await request('/auth/login', { method: 'POST', body: { email: 'user@example.com', password }, headers: { Origin: 'https://evil.example' } })).response.status, 403);
  assert.equal((await request('/auth/logout', { method: 'POST', body: {}, cookie: userCookie, headers: { 'X-Dytava-Request': '' } })).response.status, 403);
  const malformed = await fetch(`${base}/api/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Dytava-Request': '1' }, body: '{bad' }); assert.equal(malformed.status, 400);
});
test('backend enforces every admin route independent of frontend', async () => {
  for (const path of ['/admin/overview', '/admin/audit', '/admin/audit/export', '/admin/comparisons']) {
    assert.equal((await request(path)).response.status, 401);
    assert.equal((await request(path, { cookie: userCookie })).response.status, 403);
    assert.equal((await request(path, { cookie: adminCookie })).response.status, 200);
  }
  assert.equal((await request('/admin/releases', { method: 'POST', body: release, cookie: userCookie })).response.status, 403);
});
test('empty database reports zero real usage and no fake releases', async () => {
  const result = await request('/admin/overview', { cookie: adminCookie });
  assert.equal(result.data.comparisons, 0); assert.equal(result.data.cells, 0);
  assert.deepEqual((await request('/releases')).data.items, []);
});
test('history explicitly saves metadata, is idempotent and rejects raw content', async () => {
  assert.equal((await request('/comparisons', { method: 'POST', body: metadata })).response.status, 401);
  assert.equal((await request('/comparisons', { method: 'POST', cookie: userCookie, body: { ...metadata, filename: 'private.csv' } })).response.status, 400);
  const result = await request('/comparisons', { method: 'POST', cookie: userCookie, body: metadata });
  assert.equal(result.response.status, 201); savedId = result.data.item.id; assert.equal(result.data.item.metadataSha256.length, 64);
  assert.equal((await request('/comparisons', { method: 'POST', cookie: userCookie, body: metadata })).response.status, 200);
  assert.equal((await request('/comparisons', { method: 'POST', cookie: userCookie, body: { ...metadata, rowsA: 3 } })).response.status, 409);
  assert.equal((await request('/comparisons', { method: 'POST', cookie: userCookie, body: { ...metadata, clientId: randomUUID(), summary: { ...summary, total_cells_checked: 999 } } })).response.status, 400);
  assert.equal((await request('/comparisons', { cookie: userCookie })).data.total, 1);
});
test('history ownership blocks reading and deleting other users data', async () => {
  assert.equal((await request(`/comparisons/${savedId}`, { cookie: otherCookie })).response.status, 404);
  assert.equal((await request(`/comparisons/${savedId}`, { method: 'DELETE', cookie: otherCookie, body: {} })).response.status, 404);
  assert.equal((await request('/comparisons', { cookie: otherCookie })).data.total, 0);
  assert.equal((await request(`/comparisons/${savedId}`, { cookie: userCookie })).response.status, 200);
  assert.equal((await request('/comparisons?limit=-1', { cookie: userCookie })).response.status, 400);
});
test('dashboard aggregates saved metadata accurately', async () => {
  const { data } = await request('/admin/overview', { cookie: adminCookie });
  assert.equal(data.comparisons, 1); assert.equal(data.cells, 4); assert.equal(data.equivalent, 1); assert.equal(data.unresolved, 1); assert.equal(data.averageDurationMs, 42.5);
  assert.deepEqual(data.formats.map(f => [f.format, f.count]), [['csv', 1], ['xlsx', 1]]);
});
test('release CRUD persists real URL and checksum with audit, rejects unsafe URLs', async () => {
  assert.equal((await request('/admin/releases', { method: 'POST', cookie: adminCookie, body: { ...release, downloadUrl: 'javascript:alert(1)' } })).response.status, 400);
  const result = await request('/admin/releases', { method: 'POST', cookie: adminCookie, body: release }); assert.equal(result.response.status, 201);
  const id = result.data.item.id;
  assert.equal((await request('/releases')).data.items[0].downloadUrl, release.downloadUrl);
  assert.equal((await request('/admin/releases', { method: 'POST', cookie: adminCookie, body: release })).response.status, 409);
  assert.equal((await request(`/admin/releases/${id}`, { method: 'PUT', cookie: adminCookie, body: { ...release, version: '1.0.1' } })).data.item.version, '1.0.1');
  assert.equal((await request(`/admin/releases/${id}`, { method: 'DELETE', cookie: adminCookie, body: {} })).response.status, 204);
  const logs = (await request('/admin/audit', { cookie: adminCookie })).data.items;
  assert.ok(logs.some(row => row.action === 'release.created')); assert.ok(logs.some(row => row.action === 'release.deleted'));
  assert.ok(!JSON.stringify(logs).includes(release.changelog));
});
test('policy updates use optimistic concurrency and retain prior comparison snapshots', async () => {
  const body = { id: 'test-policy-v1', name: 'Test policy', description: 'A policy', config: policyConfig };
  const create = await request('/admin/policies', { method: 'POST', cookie: adminCookie, body }); assert.equal(create.response.status, 201);
  const update = { ...body, config: { ...policyConfig, tolerance_abs: 2 }, revision: 1 };
  assert.equal((await request(`/admin/policies/${body.id}`, { method: 'PUT', cookie: adminCookie, body: update })).data.item.revision, 2);
  assert.equal((await request(`/admin/policies/${body.id}`, { method: 'PUT', cookie: adminCookie, body: update })).response.status, 409);
  assert.equal((await request(`/comparisons/${savedId}`, { cookie: userCookie })).data.item.policyConfig.tolerance_abs, 0);
  assert.equal((await request(`/admin/policies/${body.id}`, { method: 'DELETE', cookie: adminCookie, body: {} })).response.status, 204);
});
test('flags persist and backend honors history kill switch', async () => {
  const flags = (await request('/config')).data.flags;
  const flag = flags.find(f => f.id === 'FLAG_HISTORY');
  const result = await request(`/admin/flags/${flag.id}`, { method: 'PATCH', cookie: adminCookie, body: { enabled: false, revision: flag.revision } }); assert.equal(result.data.item.enabled, false);
  assert.equal((await request('/comparisons', { method: 'POST', cookie: userCookie, body: { ...metadata, clientId: randomUUID() } })).response.status, 403);
  assert.equal((await request(`/admin/flags/${flag.id}`, { method: 'PATCH', cookie: adminCookie, body: { enabled: true, revision: flag.revision } })).response.status, 409);
  assert.equal((await request(`/admin/flags/${flag.id}`, { method: 'PATCH', cookie: adminCookie, body: { enabled: true, revision: flag.revision + 1 } })).response.status, 200);
});
test('password change invalidates older sessions and logout revokes current session', async () => {
  const login = await request('/auth/login', { method: 'POST', body: { email: 'other@example.com', password } });
  const result = await request('/auth/password', { method: 'POST', cookie: login.cookie, body: { currentPassword: password, newPassword: 'a-new-test-password-2026' } }); assert.equal(result.response.status, 204);
  assert.equal((await request('/auth/me', { cookie: otherCookie })).data.user, null);
  assert.equal((await request('/auth/me', { cookie: login.cookie })).data.user, null);
  assert.ok((await request('/auth/me', { cookie: result.cookie })).data.user);
  await request('/auth/logout', { method: 'POST', cookie: result.cookie, body: {} });
  assert.equal((await request('/auth/me', { cookie: result.cookie })).data.user, null);
});
test('history deletion is scoped and removes persisted rows', async () => {
  assert.equal((await request('/comparisons', { method: 'DELETE', cookie: userCookie, body: {} })).response.status, 204);
  assert.equal((await request('/comparisons', { cookie: userCookie })).data.total, 0);
  assert.equal((await request(`/comparisons/${savedId}`, { cookie: userCookie })).response.status, 404);
});
test('migrations are repeatable and data survives database close/reopen', async () => {
  const filename = join(dir, 'persistence.sqlite');
  let connection = openDatabase(filename);
  const user = await createUser(connection, { email: 'persistent@example.com', name: 'Persistent', password });
  connection.close(); connection = openDatabase(filename);
  assert.equal(connection.prepare('SELECT count(*) n FROM schema_migrations').get().n, 1);
  assert.equal(connection.prepare('SELECT name FROM users WHERE id=?').get(user.id).name, 'Persistent');
  assert.equal(connection.prepare('SELECT count(*) n FROM policies').get().n, 3);
  connection.prepare("INSERT INTO sessions VALUES('expired', ?, 0)").run(user.id);
  connection.prepare("INSERT INTO audit_logs(action,resource_id,created_at) VALUES('old','old','2000-01-01T00:00:00.000Z')").run();
  pruneDatabase(connection, 30);
  assert.equal(connection.prepare('SELECT count(*) n FROM sessions').get().n, 0);
  assert.equal(connection.prepare('SELECT count(*) n FROM audit_logs').get().n, 0);
  assert.throws(() => transaction(connection, () => { connection.prepare("UPDATE feature_flags SET enabled=0").run(); throw new Error('rollback'); }));
  assert.equal(connection.prepare('SELECT sum(enabled) n FROM feature_flags').get().n, 4);
  connection.close();
});
test('production config requires HTTPS and constrains retention', () => {
  assert.throws(() => loadConfig({ NODE_ENV: 'production', APP_ORIGIN: 'http://example.com' }));
  assert.throws(() => loadConfig({ HISTORY_RETENTION_DAYS: '-1' }));
  assert.equal(loadConfig({ NODE_ENV: 'production', APP_ORIGIN: 'https://example.com' }).production, true);
});
