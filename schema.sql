-- StreamFlix PRO — Cloudflare D1 schema
-- Run: wrangler d1 execute streamflix_db --file=./schema.sql

CREATE TABLE IF NOT EXISTS accounts (
  id TEXT PRIMARY KEY,
  host TEXT NOT NULL,
  username TEXT NOT NULL,
  created_at INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE TABLE IF NOT EXISTS profiles (
  id TEXT PRIMARY KEY,
  account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  is_kids INTEGER NOT NULL DEFAULT 0,
  pin_hash TEXT,
  created_at INTEGER NOT NULL DEFAULT (unixepoch())
);
CREATE INDEX IF NOT EXISTS idx_profiles_account ON profiles(account_id);

CREATE TABLE IF NOT EXISTS progress (
  profile_id TEXT NOT NULL,
  content_id TEXT NOT NULL,
  series_id TEXT,
  type TEXT NOT NULL,
  season INTEGER,
  episode INTEGER,
  title TEXT,
  position REAL NOT NULL DEFAULT 0,
  duration REAL NOT NULL DEFAULT 0,
  percentage REAL NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL,
  finished INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (profile_id, content_id)
);
CREATE INDEX IF NOT EXISTS idx_progress_profile ON progress(profile_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS favorites (
  profile_id TEXT NOT NULL,
  content_id TEXT NOT NULL,
  type TEXT NOT NULL,
  payload TEXT,
  added_at INTEGER NOT NULL,
  PRIMARY KEY (profile_id, content_id)
);
CREATE INDEX IF NOT EXISTS idx_favorites_profile ON favorites(profile_id, added_at DESC);

-- Optional: cached EPG rows if you later want server-side EPG aggregation
-- across providers instead of per-client get_short_epg calls.
CREATE TABLE IF NOT EXISTS epg_cache (
  channel_id TEXT PRIMARY KEY,
  payload TEXT NOT NULL,
  updated_at INTEGER NOT NULL
);
