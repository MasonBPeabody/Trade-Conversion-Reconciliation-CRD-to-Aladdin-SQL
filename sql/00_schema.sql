-- 00_schema.sql (Postgres) - Edited to drop in dependency-safe order

-- Drop CHILD tables first (due to foreign key dependencies)
DROP TABLE IF EXISTS recon_breaks;
DROP TABLE IF EXISTS break_taxonomy;

-- Drop remaining core tables
DROP TABLE IF EXISTS aladdin_trades;
DROP TABLE IF EXISTS crd_trades;
DROP TABLE IF EXISTS security_map;
DROP TABLE IF EXISTS account_map;

-- Source system (CRD)
CREATE TABLE crd_trades (
  crd_trade_id   TEXT PRIMARY KEY,
  trade_date     DATE NOT NULL,
  settle_date    DATE,
  account_id     TEXT NOT NULL,
  security_id    TEXT NOT NULL,
  side           TEXT NOT NULL, -- BUY/SELL
  quantity       NUMERIC(20,6) NOT NULL,
  price          NUMERIC(20,10),
  gross_amount   NUMERIC(20,2),
  currency       TEXT,
  trader         TEXT,
  status         TEXT, -- e.g., NEW/ALLOCATED/CONFIRMED
  created_ts     TIMESTAMP
);

-- Target system (Aladdin)
CREATE TABLE aladdin_trades (
  aladdin_trade_id  TEXT PRIMARY KEY,
  legacy_trade_id   TEXT,          -- expected to reference crd_trade_id
  trade_date        DATE NOT NULL,
  settle_date       DATE,
  account_id        TEXT NOT NULL,
  security_id       TEXT NOT NULL,
  side              TEXT NOT NULL,
  quantity          NUMERIC(20,6) NOT NULL,
  price             NUMERIC(20,10),
  gross_amount      NUMERIC(20,2),
  currency          TEXT,
  trader            TEXT,
  status            TEXT,
  created_ts        TIMESTAMP
);

-- Mapping tables (identifier normalization)
CREATE TABLE security_map (
  crd_security_id     TEXT PRIMARY KEY,
  aladdin_security_id TEXT NOT NULL
);

CREATE TABLE account_map (
  crd_account_id      TEXT PRIMARY KEY,
  aladdin_account_id  TEXT NOT NULL
);

-- Governance tables
CREATE TABLE break_taxonomy (
  break_code   TEXT PRIMARY KEY,
  severity     TEXT NOT NULL,  -- HIGH/MED/LOW
  owner_team   TEXT NOT NULL,  -- FO/Ops/Tech/Data
  description  TEXT NOT NULL
);

CREATE TABLE recon_breaks (
  break_id          BIGSERIAL PRIMARY KEY,
  break_code        TEXT NOT NULL REFERENCES break_taxonomy(break_code),
  object_type       TEXT NOT NULL, -- TRADE
  crd_trade_id      TEXT,
  aladdin_trade_id  TEXT,
  detected_at       TIMESTAMP NOT NULL DEFAULT NOW(),
  status            TEXT NOT NULL DEFAULT 'OPEN',
  details           TEXT
);

-- Indexes (performance and typical access patterns)
CREATE INDEX idx_aladdin_legacy_trade_id ON aladdin_trades(legacy_trade_id);
CREATE INDEX idx_crd_trade_date ON crd_trades(trade_date);
CREATE INDEX idx_aladdin_trade_date ON aladdin_trades(trade_date);
