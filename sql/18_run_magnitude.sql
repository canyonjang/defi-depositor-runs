-- query 18: per-wallet withdrawal MAGNITUDE for run-definition robustness (all four markets).
-- For each pre-shock depositor (bal0 >= 100), sum USDC flows in:
--   event window   [t0, t0+144h) = 2023-03-09 .. 2023-03-15   -> ev_out (gross withdrawn), ev_in (gross supplied)
--   placebo window [2023-01-15, 2023-01-21)  (a calm pre-shock 6-day window)  -> pl_out (gross withdrawn)
-- Merged with the panels (which carry bal0) this supports run defined as:
--   * gross fraction withdrawn = ev_out / bal0
--   * NET fraction withdrawn   = (ev_out - ev_in) / bal0
--   * full exit                = NET fraction >= ~0.9
--   * threshold runs           = fraction >= 10% / 25% / 50% / 90%
--   * placebo run rate         = pl_out / bal0 >= threshold  (should be near zero)
-- Output columns: owner, market, ev_out, ev_in, pl_out   (USDC, 6-dp scaled)
--
-- Addresses:  USDC 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
--             cUSDC (Comp V2) 0x39AA39c021dfbaE8faC545936693aC917d5E7563
--             cUSDCv3 (Comp V3 Comet) 0xc3d688B66703497DAA19211EEdff47f25384cdc3
-- Compound V3 tables verified: compound_v3_ethereum.cusdcv3_evt_supply (dst) / _withdraw (src).
-- Run -> export FULL result (CSV/JSON) -> save as data/run_magnitude.csv -> upload.

WITH
-- ================= Aave V2 =================
av2 AS (
  SELECT "onBehalfOf" AS o, 'sup' AS typ, CAST(amount AS double)/1e6 AS amt, evt_block_time AS t
    FROM aave_v2_ethereum.LendingPool_evt_Deposit  WHERE reserve = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
  UNION ALL
  SELECT "user"       AS o, 'wdr' AS typ, CAST(amount AS double)/1e6 AS amt, evt_block_time AS t
    FROM aave_v2_ethereum.LendingPool_evt_Withdraw WHERE reserve = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
),
av2_bal AS (SELECT o FROM (SELECT o, CASE WHEN typ='sup' THEN amt ELSE -amt END AS s FROM av2 WHERE t < TIMESTAMP '2023-03-09') u GROUP BY o HAVING SUM(s) >= 100),
av2_agg AS (
  SELECT o AS owner, 'aave_v2' AS market,
    SUM(CASE WHEN typ='wdr' AND t>=TIMESTAMP '2023-03-09' AND t<TIMESTAMP '2023-03-15' THEN amt ELSE 0 END) AS ev_out,
    SUM(CASE WHEN typ='sup' AND t>=TIMESTAMP '2023-03-09' AND t<TIMESTAMP '2023-03-15' THEN amt ELSE 0 END) AS ev_in,
    SUM(CASE WHEN typ='wdr' AND t>=TIMESTAMP '2023-01-15' AND t<TIMESTAMP '2023-01-21' THEN amt ELSE 0 END) AS pl_out
  FROM av2 WHERE o IN (SELECT o FROM av2_bal) GROUP BY o
),
-- ================= Compound V2 =================
cv2 AS (
  SELECT minter   AS o, 'sup' AS typ, CAST("mintAmount"   AS double)/1e6 AS amt, evt_block_time AS t
    FROM compound_v2_ethereum.cErc20_evt_Mint   WHERE contract_address = 0x39AA39c021dfbaE8faC545936693aC917d5E7563
  UNION ALL
  SELECT redeemer AS o, 'wdr' AS typ, CAST("redeemAmount" AS double)/1e6 AS amt, evt_block_time AS t
    FROM compound_v2_ethereum.cErc20_evt_Redeem WHERE contract_address = 0x39AA39c021dfbaE8faC545936693aC917d5E7563
),
cv2_bal AS (SELECT o FROM (SELECT o, CASE WHEN typ='sup' THEN amt ELSE -amt END AS s FROM cv2 WHERE t < TIMESTAMP '2023-03-09') u GROUP BY o HAVING SUM(s) >= 100),
cv2_agg AS (
  SELECT o AS owner, 'compound_v2' AS market,
    SUM(CASE WHEN typ='wdr' AND t>=TIMESTAMP '2023-03-09' AND t<TIMESTAMP '2023-03-15' THEN amt ELSE 0 END) AS ev_out,
    SUM(CASE WHEN typ='sup' AND t>=TIMESTAMP '2023-03-09' AND t<TIMESTAMP '2023-03-15' THEN amt ELSE 0 END) AS ev_in,
    SUM(CASE WHEN typ='wdr' AND t>=TIMESTAMP '2023-01-15' AND t<TIMESTAMP '2023-01-21' THEN amt ELSE 0 END) AS pl_out
  FROM cv2 WHERE o IN (SELECT o FROM cv2_bal) GROUP BY o
),
-- ================= Aave V3 =================
av3 AS (
  SELECT "onBehalfOf" AS o, 'sup' AS typ, CAST(amount AS double)/1e6 AS amt, evt_block_time AS t
    FROM aave_v3_ethereum.Pool_evt_Supply   WHERE reserve = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
  UNION ALL
  SELECT "user"       AS o, 'wdr' AS typ, CAST(amount AS double)/1e6 AS amt, evt_block_time AS t
    FROM aave_v3_ethereum.Pool_evt_Withdraw WHERE reserve = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
),
av3_bal AS (SELECT o FROM (SELECT o, CASE WHEN typ='sup' THEN amt ELSE -amt END AS s FROM av3 WHERE t < TIMESTAMP '2023-03-09') u GROUP BY o HAVING SUM(s) >= 100),
av3_agg AS (
  SELECT o AS owner, 'aave_v3' AS market,
    SUM(CASE WHEN typ='wdr' AND t>=TIMESTAMP '2023-03-09' AND t<TIMESTAMP '2023-03-15' THEN amt ELSE 0 END) AS ev_out,
    SUM(CASE WHEN typ='sup' AND t>=TIMESTAMP '2023-03-09' AND t<TIMESTAMP '2023-03-15' THEN amt ELSE 0 END) AS ev_in,
    SUM(CASE WHEN typ='wdr' AND t>=TIMESTAMP '2023-01-15' AND t<TIMESTAMP '2023-01-21' THEN amt ELSE 0 END) AS pl_out
  FROM av3 WHERE o IN (SELECT o FROM av3_bal) GROUP BY o
),
-- ================= Compound V3 (Comet) =================
cv3 AS (
  SELECT dst AS o, 'sup' AS typ, CAST(amount AS double)/1e6 AS amt, evt_block_time AS t
    FROM compound_v3_ethereum.cusdcv3_evt_supply
  UNION ALL
  SELECT src AS o, 'wdr' AS typ, CAST(amount AS double)/1e6 AS amt, evt_block_time AS t
    FROM compound_v3_ethereum.cusdcv3_evt_withdraw
),
cv3_bal AS (SELECT o FROM (SELECT o, CASE WHEN typ='sup' THEN amt ELSE -amt END AS s FROM cv3 WHERE t < TIMESTAMP '2023-03-09') u GROUP BY o HAVING SUM(s) >= 100),
cv3_agg AS (
  SELECT o AS owner, 'compound_v3' AS market,
    SUM(CASE WHEN typ='wdr' AND t>=TIMESTAMP '2023-03-09' AND t<TIMESTAMP '2023-03-15' THEN amt ELSE 0 END) AS ev_out,
    SUM(CASE WHEN typ='sup' AND t>=TIMESTAMP '2023-03-09' AND t<TIMESTAMP '2023-03-15' THEN amt ELSE 0 END) AS ev_in,
    SUM(CASE WHEN typ='wdr' AND t>=TIMESTAMP '2023-01-15' AND t<TIMESTAMP '2023-01-21' THEN amt ELSE 0 END) AS pl_out
  FROM cv3 WHERE o IN (SELECT o FROM cv3_bal) GROUP BY o
)
SELECT * FROM av2_agg
UNION ALL SELECT * FROM cv2_agg
UNION ALL SELECT * FROM av3_agg
UNION ALL SELECT * FROM cv3_agg
