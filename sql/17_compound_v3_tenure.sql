-- query 17: in-protocol deposit TENURE for Compound V3 (Comet USDC market).
-- Completes the four-market tenure analysis (adds the base-asset market that query 16 omitted),
-- so the "all four markets" claim is fully supported and Compound V3 can enter the
-- market-fixed-effects and per-market tenure regressions.
-- Output columns MATCH data/tenure.csv exactly: owner, proto, first_supply, tenure_days
-- Conventions identical to query 16: t0 = 2023-03-09; restrict to bal0 >= 100 universe.
--
-- Comet USDC market (cUSDCv3, Ethereum): 0xc3d688B66703497DAA19211EEdff47f25384cdc3
-- Base-asset events (USDC is the base asset of this Comet deployment):
--   Supply(from, dst, amount)     -> a base-asset supply; owner = dst (account credited)
--   Withdraw(src, to, amount)     -> a base-asset withdrawal; owner = src
--   amount in USDC (6 decimals)
--
-- Tables verified: compound_v3_ethereum.cusdcv3_evt_supply (owner=dst) and _withdraw (owner=src),
-- amount in USDC (6dp). These tables are cUSDCv3-specific, so no contract_address filter is needed.
--
-- Run -> export FULL result (CSV/JSON) -> save as data/compound_v3_tenure.csv -> upload.

WITH
sup AS (
  SELECT dst AS o, CAST(amount AS double)/1e6 AS a, evt_block_time AS t
  FROM compound_v3_ethereum.cusdcv3_evt_supply
),
wdr AS (
  SELECT src AS o, CAST(amount AS double)/1e6 AS a, evt_block_time AS t
  FROM compound_v3_ethereum.cusdcv3_evt_withdraw
),
bal AS (   -- panel universe: net USDC supplied >= 100 immediately before t0
  SELECT o FROM (
      SELECT o,  a AS s FROM sup WHERE t < TIMESTAMP '2023-03-09'
      UNION ALL
      SELECT o, -a       FROM wdr WHERE t < TIMESTAMP '2023-03-09'
  ) u
  GROUP BY o HAVING SUM(s) >= 100
),
first_sup AS (
  SELECT o AS owner, MIN(t) AS first_supply
  FROM sup WHERE t < TIMESTAMP '2023-03-09' AND o IN (SELECT o FROM bal)
  GROUP BY o
)
SELECT owner,
       'compound_v3' AS proto,
       first_supply,
       date_diff('day', first_supply, TIMESTAMP '2023-03-09') AS tenure_days
FROM first_sup
