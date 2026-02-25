-- 03_break_taxonomy_and_reports.sql

-- Break taxonomy (customize to your operating model)
INSERT INTO break_taxonomy (break_code, severity, owner_team, description) VALUES
('MISSING_IN_ALADDIN','HIGH','Tech','CRD trade not found in Aladdin within conversion window'),
('NO_LEGACY_ID','MED','Tech','Aladdin trade missing legacy trade identifier'),
('DUP_LEGACY_ID','HIGH','Tech','Multiple Aladdin trades share the same legacy_trade_id'),
('MAP_MISSING_ACCT','HIGH','Data','Account mapping missing for CRD account_id'),
('MAP_MISSING_SEC','HIGH','Data','Security mapping missing for CRD security_id'),
('MISMATCH_QTY','HIGH','Ops','Quantity mismatch across systems'),
('MISMATCH_PRICE','MED','Ops','Price mismatch beyond tolerance'),
('MISMATCH_GROSS','MED','Ops','Gross amount mismatch beyond tolerance'),
('MISMATCH_DATES','LOW','Ops','Trade/settle date mismatch');

-- Conversion window and tolerances
WITH params AS (
  SELECT
    DATE '2026-01-01' AS start_date,
    DATE '2026-01-31' AS end_date,
    0.0001::NUMERIC AS price_tol,
    1.00::NUMERIC   AS gross_tol
),
crd_norm AS (
  SELECT
    c.crd_trade_id,
    c.trade_date,
    c.settle_date,
    c.account_id AS crd_account_id,
    c.security_id AS crd_security_id,
    am.aladdin_account_id AS exp_account_id,
    sm.aladdin_security_id AS exp_security_id,
    c.side,
    c.quantity,
    c.price,
    c.gross_amount,
    c.currency,
    c.trader,
    c.status
  FROM crd_trades c
  JOIN params p
    ON c.trade_date BETWEEN p.start_date AND p.end_date
  LEFT JOIN account_map am
    ON am.crd_account_id = c.account_id
  LEFT JOIN security_map sm
    ON sm.crd_security_id = c.security_id
),
ald AS (
  SELECT a.*
  FROM aladdin_trades a
  JOIN params p
    ON a.trade_date BETWEEN p.start_date AND p.end_date
),

-- A) Mapping gaps
map_breaks AS (
  SELECT
    CASE
      WHEN exp_account_id IS NULL THEN 'MAP_MISSING_ACCT'
      WHEN exp_security_id IS NULL THEN 'MAP_MISSING_SEC'
      ELSE NULL
    END AS break_code,
    crd_trade_id,
    NULL::TEXT AS aladdin_trade_id,
    CONCAT('crd_account_id=', crd_account_id, ', crd_security_id=', crd_security_id) AS details
  FROM crd_norm
  WHERE exp_account_id IS NULL OR exp_security_id IS NULL
),

-- B) Missing in Aladdin
missing_breaks AS (
  SELECT
    'MISSING_IN_ALADDIN' AS break_code,
    c.crd_trade_id,
    NULL::TEXT AS aladdin_trade_id,
    'No matching Aladdin trade by legacy_trade_id' AS details
  FROM crd_norm c
  LEFT JOIN ald a
    ON a.legacy_trade_id = c.crd_trade_id
  WHERE a.legacy_trade_id IS NULL
),

-- C) Duplicate legacy ids
dup_breaks AS (
  SELECT
    'DUP_LEGACY_ID' AS break_code,
    legacy_trade_id AS crd_trade_id,
    NULL::TEXT AS aladdin_trade_id,
    CONCAT('aladdin_rows=', COUNT(*)) AS details
  FROM ald
  WHERE legacy_trade_id IS NOT NULL AND legacy_trade_id <> ''
  GROUP BY legacy_trade_id
  HAVING COUNT(*) > 1
),

-- D) Field-level mismatches
field_breaks AS (
  SELECT
    c.crd_trade_id,
    a.aladdin_trade_id,
    CASE
      WHEN a.legacy_trade_id IS NULL THEN NULL
      WHEN a.account_id <> c.exp_account_id THEN 'MAP_MISSING_ACCT' -- or 'MISMATCH_ACCOUNT' if you add it
      WHEN a.security_id <> c.exp_security_id THEN 'MAP_MISSING_SEC' -- or 'MISMATCH_SECURITY'
      WHEN a.side <> c.side THEN 'MISMATCH_QTY' -- keep simple; you can add MISMATCH_SIDE
      WHEN a.quantity <> c.quantity THEN 'MISMATCH_QTY'
      WHEN c.price IS NOT NULL AND a.price IS NOT NULL AND ABS(a.price - c.price) > (SELECT price_tol FROM params) THEN 'MISMATCH_PRICE'
      WHEN c.gross_amount IS NOT NULL AND a.gross_amount IS NOT NULL AND ABS(a.gross_amount - c.gross_amount) > (SELECT gross_tol FROM params) THEN 'MISMATCH_GROSS'
      WHEN a.trade_date <> c.trade_date OR a.settle_date <> c.settle_date THEN 'MISMATCH_DATES'
      ELSE NULL
    END AS break_code,
    CONCAT(
      'exp_account_id=', c.exp_account_id, ', ald_account_id=', a.account_id,
      '; exp_security_id=', c.exp_security_id, ', ald_security_id=', a.security_id,
      '; crd_qty=', c.quantity, ', ald_qty=', a.quantity,
      '; crd_price=', c.price, ', ald_price=', a.price,
      '; crd_gross=', c.gross_amount, ', ald_gross=', a.gross_amount,
      '; crd_td=', c.trade_date, ', ald_td=', a.trade_date,
      '; crd_sd=', c.settle_date, ', ald_sd=', a.settle_date
    ) AS details
  FROM crd_norm c
  JOIN ald a
    ON a.legacy_trade_id = c.crd_trade_id
)

-- Insert breaks into recon_breaks (idempotency note: for demos, truncate first)
-- TRUNCATE TABLE recon_breaks;

INSERT INTO recon_breaks (break_code, object_type, crd_trade_id, aladdin_trade_id, details)
SELECT break_code, 'TRADE', crd_trade_id, aladdin_trade_id, details
FROM (
  SELECT * FROM map_breaks
  UNION ALL
  SELECT * FROM missing_breaks
  UNION ALL
  SELECT * FROM dup_breaks
  UNION ALL
  SELECT break_code, crd_trade_id, aladdin_trade_id, details
  FROM field_breaks
  WHERE break_code IS NOT NULL
) x
WHERE break_code IS NOT NULL;

-- Break report (audit-ready)
-- SELECT * FROM recon_breaks ORDER BY detected_at DESC, break_code;
