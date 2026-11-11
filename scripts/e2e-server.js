import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { openDatabase } from '../server/db.js';
import { createApp } from '../server/app.js';
import { createUser } from '../server/auth.js';

const dir = mkdtempSync(join(tmpdir(), 'dytava-e2e-'));
const db = openDatabase(join(dir, 'e2e.sqlite'));
await createUser(db, { email: 'admin@e2e.example', name: 'E2E Admin', password: 'e2e-test-password-only', role: 'admin' });
const config = { origin: 'http://127.0.0.1:4317', production: false, trustProxy: false, staticDir: resolve('dist'), sessionDays: 7, retentionDays: 30, allowRegistration: true };
const app = await createApp({ db, config });
const server = app.listen(4317, '127.0.0.1');
process.on('SIGTERM', () => server.close(() => { db.close(); rmSync(dir, { recursive: true, force: true }); process.exit(0); }));
