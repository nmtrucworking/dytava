CREATE TABLE users (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL UNIQUE COLLATE NOCASE,
  name TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'user' CHECK(role IN ('user', 'admin')),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
) STRICT;
CREATE TABLE sessions (
  token_hash TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at INTEGER NOT NULL
) STRICT;
CREATE INDEX sessions_expiry ON sessions(expires_at);
CREATE TABLE releases (
  id TEXT PRIMARY KEY,
  product TEXT NOT NULL,
  platform TEXT NOT NULL,
  version TEXT NOT NULL,
  stage TEXT NOT NULL CHECK(stage IN ('Stable', 'Beta', 'Production')),
  size TEXT NOT NULL,
  sha256 TEXT NOT NULL,
  download_url TEXT NOT NULL,
  changelog TEXT NOT NULL,
  release_date TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  UNIQUE(product, platform, version)
) STRICT;
CREATE TABLE policies (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  config TEXT NOT NULL CHECK(json_valid(config)),
  revision INTEGER NOT NULL DEFAULT 1,
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
) STRICT;
CREATE TABLE feature_flags (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  enabled INTEGER NOT NULL CHECK(enabled IN (0, 1)),
  revision INTEGER NOT NULL DEFAULT 1
) STRICT;
CREATE TABLE comparisons (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  client_id TEXT NOT NULL,
  format_a TEXT NOT NULL,
  format_b TEXT NOT NULL,
  rows_a INTEGER NOT NULL,
  rows_b INTEGER NOT NULL,
  duration_ms REAL NOT NULL,
  policy_id TEXT NOT NULL,
  policy_config TEXT NOT NULL CHECK(json_valid(policy_config)),
  summary TEXT NOT NULL CHECK(json_valid(summary)),
  metadata_sha256 TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  UNIQUE(user_id, client_id)
) STRICT;
CREATE INDEX comparisons_user_created ON comparisons(user_id, created_at DESC);
CREATE INDEX comparisons_created ON comparisons(created_at);
CREATE TABLE audit_logs (
  id INTEGER PRIMARY KEY,
  actor_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  resource_id TEXT NOT NULL,
  details TEXT NOT NULL DEFAULT '{}' CHECK(json_valid(details)),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
) STRICT;
CREATE INDEX audit_created ON audit_logs(created_at DESC);
