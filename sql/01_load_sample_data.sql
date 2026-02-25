-- 01_load_sample_data.sql (Postgres)
-- Option A: load from CSVs (recommended once you add /data/*.csv)

-- \copy crd_trades FROM 'data/crd_trades.csv' WITH (FORMAT csv, HEADER true);
-- \copy aladdin_trades FROM 'data/aladdin_trades.csv' WITH (FORMAT csv, HEADER true);
-- \copy security_map FROM 'data/security_map.csv' WITH (FORMAT csv, HEADER true);
-- \copy account_map FROM 'data/account_map.csv' WITH (FORMAT csv, HEADER true);

-- Option B: minimal inline sample data (works immediately)

INSERT INTO security_map (crd_security_id, aladdin_security_id) VALUES
('CUSIP123', 'ALADDIN_SEC_001'),
('CUSIP456', 'ALADDIN_SEC_002');

INSERT INTO account_map (crd_account_id, aladdin_account_id) VALUES
('ACCT_A', 'ALD_ACCT_100'),
('ACCT_B', 'ALD_ACCT_200');

INSERT INTO crd_trades
(crd_trade_id, trade_date, settle_date, account_id, security_id, side, quantity, price, gross_amount, currency, trader, status, created_ts)
VALUES
('T1','2026-01-05','2026-01-07','ACCT_A','CUSIP123','BUY', 100, 99.125, 9912.50,'USD','TRDR1','CONFIRMED','2026-01-05 10:00:00'),
('T2','2026-01-05','2026-01-07','ACCT_A','CUSIP456','SELL',200, 101.50, 20300.00,'USD','TRDR2','CONFIRMED','2026-01-05 10:05:00'),
('T3','2026-01-06','2026-01-08','ACCT_B','CUSIP123','BUY', 150, 99.125, 14868.75,'USD','TRDR1','CONFIRMED','2026-01-06 09:30:00');

INSERT INTO aladdin_trades
(aladdin_trade_id, legacy_trade_id, trade_date, settle_date, account_id, security_id, side, quantity, price, gross_amount, currency, trader, status, created_ts)
VALUES
('A100','T1','2026-01-05','2026-01-07','ALD_ACCT_100','ALADDIN_SEC_001','BUY',100, 99.1250, 9912.50,'USD','TRDR1','CONFIRMED','2026-01-05 11:00:00'),
('A200','T2','2026-01-05','2026-01-07','ALD_ACCT_100','ALADDIN_SEC_002','SELL',200, 101.5000, 20300.00,'USD','TRDR2','CONFIRMED','2026-01-05 11:02:00'),
-- Intentional difference: quantity mismatch to demonstrate a break
('A300','T3','2026-01-06','2026-01-08','ALD_ACCT_200','ALADDIN_SEC_001','BUY',149, 99.1250, 14769.63,'USD','TRDR1','CONFIRMED','2026-01-06 10:00:00');
