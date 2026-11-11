import { backup } from 'node:sqlite';
import { mkdirSync, chmodSync } from 'node:fs';
import { resolve } from 'node:path';
import { loadConfig } from '../server/config.js';
import { openDatabase } from '../server/db.js';

mkdirSync('backups', { recursive: true, mode: 0o700 });
const destination = resolve('backups', `dytava-${new Date().toISOString().replace(/[:.]/g, '-')}.sqlite`);
const db = openDatabase(loadConfig().databasePath);
try {
  await backup(db, destination);
  chmodSync(destination, 0o600);
  console.log(`Backup nhất quán đã lưu: ${destination}`);
} finally { db.close(); }
