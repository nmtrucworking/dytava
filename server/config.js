import 'dotenv/config';
import { resolve } from 'node:path';

export function loadConfig(env = process.env) {
  const port = Number(env.PORT || 3000);
  const production = env.NODE_ENV === 'production';
  const origin = env.APP_ORIGIN || `http://localhost:${port}`;
  const parsed = new URL(origin);
  if (parsed.origin !== origin || (production && parsed.protocol !== 'https:')) {
    throw new Error('APP_ORIGIN phải là origin hợp lệ, không có dấu / cuối; production bắt buộc HTTPS.');
  }
  const sessionDays = Number(env.SESSION_DAYS || 7);
  const retentionDays = Number(env.HISTORY_RETENTION_DAYS || 30);
  if (!Number.isInteger(port) || port < 0 || port > 65535 || !Number.isInteger(sessionDays) || sessionDays < 1 || sessionDays > 30 || !Number.isInteger(retentionDays) || retentionDays < 1 || retentionDays > 365) {
    throw new Error('PORT, SESSION_DAYS hoặc HISTORY_RETENTION_DAYS không hợp lệ.');
  }
  return {
    port, production, origin, sessionDays, retentionDays,
    host: env.HOST || '127.0.0.1',
    databasePath: resolve(env.DATABASE_PATH || './data/dytava.sqlite'),
    trustProxy: env.TRUST_PROXY === '1' ? 1 : false,
    allowRegistration: env.ALLOW_REGISTRATION !== 'false',
    staticDir: resolve('dist')
  };
}
