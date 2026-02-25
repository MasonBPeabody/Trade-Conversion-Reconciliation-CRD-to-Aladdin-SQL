-- 02_recon_checks.sql (Postgres)
-- Populates recon_breaks for CRD -> Aladdin conversion validation

-- Re-run safety: clear prior breaks (keeps taxonomy intact)
TRUNCATE TABLE recon_breaks RESTART IDENTITY;

WITH params AS (
  SELECT
    DATE '2026-01-01' AS start_date,
    DATE '2026-01-31' AS end_date,
    0.0001::NUMERIC AS price_tol,
    1.00::NUMERIC   AS gross_tol
),

-- Normalize CRD into expected Aladdin identifiers via mapping tables
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

-- A) Mapping gaps (prevents deterministic match validation)
map_breaks AS (
  SELECT
    CASE
      WHEN exp_account_id IS NULL THEN 'MAP_MISSING_ACCT'
      WHEN exp_security_id IS NULL THEN 'MAP_MISSING_SEC'
      ELSE NULL
    END AS break_code,
    crd_trade_id,
    NULL::TEXT AS aladdin_trade_id,
    CONCAT('crd_account_id=', crd_account_id, '; crd_security_id=', crd_security_id) AS details
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

-- C) Aladdin trades missing legacy id
no_legacy_breaks AS (
  SELECT
    'NO_LEGACY_ID' AS break_code,
    NULL::TEXT AS crd_trade_id,
    a.aladdin_trade_id,
    'Aladdin trade missing legacy_trade_id' AS details
  FROM ald a
  WHERE a.legacy_trade_id IS NULL OR a.legacy_trade_id = ''
),

-- D) Duplicate legacy ids
dup_breaks AS (
  SELECT
    'DUP_LEGACY_ID' AS break_code,
    a.legacy_trade_id AS crd_trade_id,
    NULL::TEXT AS aladdin_trade_id,
    CONCAT('aladdin_rows=', COUNT(*)) AS details
  FROM ald a
  WHERE a.legacy_trade_id IS NOT NULL AND a.legacy_trade_id <> ''
  GROUP BY a.legacy_trade_id
  HAVING COUNT(*) > 1
),

-- E) Field-level mismatches for deterministically matched trades
field_breaks AS (
  SELECT
    c.crd_trade_id,
    a.aladdin_trade_id,
    CASE
      WHEN a.account_id <> c.exp_account_id THEN 'MAP_MISSING_ACCT'
      WHEN a.security_id <> c.exp_security_id THEN 'MAP_MISSING_SEC'
      WHEN a.side <> c.side THEN 'MISMATCH_SIDE'
      WHEN a.quantity <> c.quantity THEN 'MISMATCH_QTY'
      WHEN c.price IS NOT NULL AND a.price IS NOT NULL
           AND ABS(a.price - c.price) > (SELECT price_tol FROM params) THEN 'MISMATCH_PRICE'
      WHEN c.gross_amount IS NOT NULL AND a.gross_amount IS NOT NULL
           AND ABS(a.gross_amount - c.gross_amount) > (SELECT gross_tol FROM params) THEN 'MISMATCH_GROSS'
      WHEN a.trade_date <> c.trade_date OR a.settle_date <> c.settle_date THEN 'MISMATCH_DATES'
      ELSE NULL
    END AS break_code,
    CONCAT(
      'exp_account_id=', c.exp_account_id, ', ald_account_id=', a.account_id,
      '; exp_security_id=', c.exp_security_id, ', ald_security_id=', a.security_id,
      '; crd_side=', c.side, ', ald_side=', a.side,
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

INSERT INTO recon_breaks (break_code, object_type, crd_trade_id, aladdin_trade_id, details)
SELECT break_code, 'TRADE', crd_trade_id, aladdin_trade_id, details
FROM (
  SELECT break_code, crd_trade_id, aladdin_trade_id, details FROM map_breaks
  UNION ALL
  SELECT break_code, crd_trade_id, aladdin_trade_id, details FROM missing_breaks
  UNION ALL
  SELECT break_code, crd_trade_id, aladdin_trade_id, details FROM no_legacy_breaks
  UNION ALL
  SELECT break_code, crd_trade_id, aladdin_trade_id, details FROM dup_breaks
  UNION ALL
  SELECT break_code, crd_trade_id, aladdin_trade_id, details
  FROM field_breaks
  WHERE break_code IS NOT NULL
) x
WHERE break_code IS NOT NULL;
