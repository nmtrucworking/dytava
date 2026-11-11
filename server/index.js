import { existsSync } from 'node:fs';
import { loadConfig } from './config.js';
import { openDatabase, pruneDatabase } from './db.js';
import { createApp } from './app.js';

const config = loadConfig();
if (!existsSync(`${config.staticDir}/index.html`)) throw new Error('Chạy npm run build trước khi khởi động.');
const db = openDatabase(config.databasePath);
pruneDatabase(db, config.retentionDays);
const app = await createApp({ db, config });
const server = app.listen(config.port, config.host, () => console.log(`Dytava đang chạy tại ${config.origin}`));
const cleanup = setInterval(() => pruneDatabase(db, config.retentionDays), 60 * 60 * 1000);
cleanup.unref();
let stopping = false;
function shutdown() {
  if (stopping) return;
  stopping = true;
  clearInterval(cleanup);
  server.close(() => { db.close(); process.exit(0); });
  setTimeout(() => process.exit(1), 10000).unref();
}
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
