import { DatabaseSync } from 'node:sqlite';
import { mkdirSync, readFileSync, readdirSync, chmodSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const migrations = fileURLToPath(new URL('./migrations/', import.meta.url));

export function transaction(db, fn) {
  db.exec('BEGIN IMMEDIATE');
  try {
    const result = fn();
    db.exec('COMMIT');
    return result;
  } catch (error) {
    db.exec('ROLLBACK');
    throw error;
  }
}

export function openDatabase(filename) {
  if (filename !== ':memory:') mkdirSync(dirname(resolve(filename)), { recursive: true, mode: 0o700 });
  const db = new DatabaseSync(filename);
  if (filename !== ':memory:') chmodSync(filename, 0o600);
  db.exec('PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON; PRAGMA busy_timeout=5000;');
  db.exec('CREATE TABLE IF NOT EXISTS schema_migrations (name TEXT PRIMARY KEY, applied_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)');
  for (const name of readdirSync(migrations).filter(n => n.endsWith('.sql')).sort()) {
    if (!db.prepare('SELECT 1 FROM schema_migrations WHERE name=?').get(name)) {
      transaction(db, () => {
        db.exec(readFileSync(resolve(migrations, name), 'utf8'));
        db.prepare('INSERT INTO schema_migrations(name) VALUES(?)').run(name);
      });
    }
  }
  transaction(db, () => {
    const policy = db.prepare('INSERT OR IGNORE INTO policies(id,name,description,config) VALUES(?,?,?,?)');
    for (const [id, name, description] of [
      ['academic-records-v1', 'Bảng điểm & hồ sơ học tập', 'Bảo toàn mã định danh, phân biệt dấu tiếng Việt, dung sai bằng 0.'],
      ['financial-audit-v2', 'Đối soát tài chính', 'Phân biệt ô trống với số 0, chuẩn hóa phần trăm, dung sai bằng 0.'],
      ['inventory-sku-v1', 'Kiểm kê kho vận', 'Giữ số 0 đầu SKU và phân biệt hoa thường của mã định danh.']
    ]) policy.run(id, name, description, JSON.stringify({ tolerance_abs: 0, preserve_leading_zeros: true, case_sensitive_identifier: true, case_sensitive_text: false, trim_text: true, distinct_null_zero: true }));
    const flag = db.prepare('INSERT OR IGNORE INTO feature_flags(id,name,description,enabled) VALUES(?,?,?,?)');
    for (const row of [
      ['FLAG_OFFLINE_XLSX_CSV', 'Nhập tệp cục bộ', 'Cho phép đọc XLSX, CSV, TSV, TXT và JSON trong trình duyệt.', 1],
      ['FLAG_KEY_ALIGNMENT', 'Căn chỉnh theo cột khóa', 'Cho phép ghép dòng theo khóa duy nhất.', 1],
      ['FLAG_REPORT_EXPORT', 'Xuất báo cáo', 'Cho phép xuất CSV và JSON từ trình duyệt.', 1],
      ['FLAG_HISTORY', 'Lưu thống kê phiên', 'Cho phép người dùng chủ động lưu thống kê, không gửi nội dung hay tên tệp.', 1]
    ]) flag.run(...row);
  });
  return db;
}

export function pruneDatabase(db, retentionDays) {
  db.prepare('DELETE FROM sessions WHERE expires_at <= ?').run(Date.now());
  const cutoff = new Date(Date.now() - retentionDays * 86400000).toISOString();
  db.prepare('DELETE FROM comparisons WHERE created_at < ?').run(cutoff);
  db.prepare('DELETE FROM audit_logs WHERE created_at < ?').run(cutoff);
}
