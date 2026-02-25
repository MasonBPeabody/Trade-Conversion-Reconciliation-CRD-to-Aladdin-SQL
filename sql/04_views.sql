-- Open breaks with aging (good for Ops control reporting)
CREATE OR REPLACE VIEW v_open_breaks AS
SELECT
  b.break_id,
  b.detected_at,
  (CURRENT_DATE - b.detected_at::date) AS age_days,
  b.status,
  b.break_code,
  t.severity,
  t.owner_team,
  b.crd_trade_id,
  b.aladdin_trade_id,
  b.details
FROM recon_breaks b
JOIN break_taxonomy t ON t.break_code = b.break_code
WHERE b.status = 'OPEN';

-- Summary by severity/owner (good for BI dashboards)
CREATE OR REPLACE VIEW v_break_summary AS
SELECT
  t.severity,
  t.owner_team,
  b.break_code,
  COUNT(*) AS break_count,
  SUM(CASE WHEN b.status = 'OPEN' THEN 1 ELSE 0 END) AS open_count,
  SUM(CASE WHEN b.status = 'CLOSED' THEN 1 ELSE 0 END) AS closed_count
FROM recon_breaks b
JOIN break_taxonomy t ON t.break_code = b.break_code
GROUP BY t.severity, t.owner_team, b.break_code
ORDER BY
  CASE t.severity WHEN 'HIGH' THEN 1 WHEN 'MED' THEN 2 ELSE 3 END,
  t.owner_team,
  b.break_code;
