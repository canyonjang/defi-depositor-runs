-- query 15: Aave V3 (USDC, Ethereum) depositor panel — vintage control.
-- Aave V3 = NEW protocol generation (Ethereum mainnet launched Jan 2023) but POOLED,
--           cross-collateral architecture (structurally like Aave V2 / Compound V2).
-- Purpose: separate ARCHITECTURE from VINTAGE. If this newer-but-pooled market runs LOW
--          (like Aave V2 / Compound V2) rather than HIGH (like the newer base-asset Compound V3),
--          the participation gap is driven by base-asset architecture, not by protocol newness.
--
-- Output columns matched to the other panels (merges directly):
--   owner, bal0, tx_sent_count, wallet_age_days, ran, first_wd_hours
-- Conventions IDENTICAL to the other panels (do not change):
--   t0 / onset = 2023-03-09 00:00 UTC ; run window = [t0, t0+144h) ; amounts USDC (6 dp)
--   bal0 >= 100 applied at panel-build time (keeps the export small; analysis uses bal>=100 anyway)
--
-- USDC reserve: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48  (same token as the V2 query)
--
-- >>> Table-name check (once): run  SELECT * FROM aave_v3_ethereum.Pool_evt_Supply LIMIT 5
--     Confirm columns include reserve, "onBehalfOf", amount. Aave V3 renamed Deposit -> Supply.
--     Withdraw event columns: reserve, "user", amount.
--     If names differ, paste the USDC address into the Data explorer search to find the decoded
--     aave_v3 Supply / Withdraw tables, and tell me the exact names.
--
-- Run -> export FULL result (CSV or JSON) -> save as data/aave_v3_usdc_panel.csv -> upload.

WITH
dep AS (   -- USDC supplied
  SELECT "onBehalfOf" AS owner, CAST(amount AS double)/1e6 AS amt, evt_block_time AS ts
  FROM aave_v3_ethereum.Pool_evt_Supply
  WHERE reserve = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
),
wdr AS (   -- USDC withdrawn
  SELECT "user" AS owner, CAST(amount AS double)/1e6 AS amt, evt_block_time AS ts
  FROM aave_v3_ethereum.Pool_evt_Withdraw
  WHERE reserve = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
),
bal AS (   -- panel universe: net USDC supplied >= 100 immediately before t0. bal0 = pre-shock balance.
  SELECT owner, SUM(s) AS bal0
  FROM (
      SELECT owner,  amt AS s FROM dep WHERE ts < TIMESTAMP '2023-03-09'
      UNION ALL
      SELECT owner, -amt AS s FROM wdr WHERE ts < TIMESTAMP '2023-03-09'
  ) u
  GROUP BY owner
  HAVING SUM(s) >= 100
),
runs AS (   -- first withdrawal in the 6-day run window
  SELECT owner, MIN(ts) AS first_wd
  FROM wdr
  WHERE ts >= TIMESTAMP '2023-03-09'
    AND ts <  TIMESTAMP '2023-03-09' + INTERVAL '144' HOUR
    AND owner IN (SELECT owner FROM bal)
  GROUP BY owner
),
tx AS (     -- wallet-level activity & age (protocol-independent; same construction as other panels)
  SELECT "from" AS owner, COUNT(*) AS tx_sent_count, MIN(block_time) AS first_tx
  FROM ethereum.transactions
  WHERE block_time < TIMESTAMP '2023-03-09' AND "from" IN (SELECT owner FROM bal)
  GROUP BY "from"
)
SELECT
  b.owner,
  b.bal0,
  COALESCE(t.tx_sent_count, 0)                          AS tx_sent_count,
  date_diff('day',  t.first_tx, TIMESTAMP '2023-03-09') AS wallet_age_days,
  CASE WHEN r.owner IS NOT NULL THEN 1 ELSE 0 END       AS ran,
  date_diff('hour', TIMESTAMP '2023-03-09', r.first_wd) AS first_wd_hours
FROM bal b
LEFT JOIN runs r ON r.owner = b.owner
LEFT JOIN tx   t ON t.owner = b.owner
