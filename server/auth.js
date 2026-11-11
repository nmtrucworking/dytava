import { randomBytes, createHash, scrypt as scryptCallback, timingSafeEqual, randomUUID } from 'node:crypto';
import { promisify } from 'node:util';

const scrypt = promisify(scryptCallback);
export const hashToken = token => createHash('sha256').update(token).digest('hex');
const cookieName = 'dytava_session';

export async function hashPassword(password) {
  const salt = randomBytes(16).toString('hex');
  const key = await scrypt(password, salt, 64, { N: 32768, r: 8, p: 1, maxmem: 64 * 1024 * 1024 });
  return `scrypt$${salt}$${key.toString('hex')}`;
}

export async function verifyPassword(password, stored) {
  const [, salt, hex] = stored.split('$');
  const key = await scrypt(password, salt, 64, { N: 32768, r: 8, p: 1, maxmem: 64 * 1024 * 1024 });
  return timingSafeEqual(key, Buffer.from(hex, 'hex'));
}

export async function createUser(db, { email, name, password, role = 'user' }) {
  const id = randomUUID();
  const hash = await hashPassword(password);
  db.prepare('INSERT INTO users(id,email,name,password_hash,role) VALUES(?,?,?,?,?)').run(id, email.toLowerCase(), name, hash, role);
  return { id, email: email.toLowerCase(), name, role };
}

export function publicUser(row) {
  return { id: row.id, email: row.email, name: row.name, role: row.role };
}

export function sessionMiddleware(db) {
  return (req, _res, next) => {
    const token = (req.headers.cookie || '').split(';').map(s => s.trim()).find(s => s.startsWith(`${cookieName}=`))?.slice(cookieName.length + 1);
    if (token && /^[a-f0-9]{64}$/.test(token)) {
      req.sessionHash = hashToken(token);
      const row = db.prepare('SELECT u.* FROM sessions s JOIN users u ON s.user_id=u.id WHERE s.token_hash=? AND s.expires_at>?').get(req.sessionHash, Date.now());
      if (row) req.user = publicUser(row);
    }
    next();
  };
}

export function setSession(db, req, res, userId, config) {
  if (req.sessionHash) db.prepare('DELETE FROM sessions WHERE token_hash=?').run(req.sessionHash);
  const token = randomBytes(32).toString('hex');
  const maxAge = config.sessionDays * 86400000;
  db.prepare('INSERT INTO sessions(token_hash,user_id,expires_at) VALUES(?,?,?)').run(hashToken(token), userId, Date.now() + maxAge);
  res.cookie(cookieName, token, { httpOnly: true, secure: config.production, sameSite: 'strict', path: '/', maxAge });
}

export function clearSession(res, config) {
  res.clearCookie(cookieName, { httpOnly: true, secure: config.production, sameSite: 'strict', path: '/' });
}

export function requireUser(req, res, next) {
  if (!req.user) return res.status(401).json({ error: 'Vui lòng đăng nhập.' });
  next();
}

export function requireAdmin(req, res, next) {
  if (!req.user) return res.status(401).json({ error: 'Vui lòng đăng nhập.' });
  if (req.user.role !== 'admin') return res.status(403).json({ error: 'Tài khoản không có quyền quản trị.' });
  next();
}
