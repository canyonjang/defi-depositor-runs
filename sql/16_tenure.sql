-- query 16: in-protocol deposit TENURE (first USDC supply date) for panel wallets.
-- Purpose: test whether the cross-protocol participation gap is a TENURE / deposit-relationship
--   effect (short relationship -> runs more; cf. Iyer & Puri 2012) rather than protocol identity.
--   If short-tenure depositors in the OLD markets run at the elevated rates of the NEW markets,
--   and tenure absorbs the new-generation dummy, tenure is the mechanism behind the vintage effect.
-- Markets (all use CONFIRMED tables from queries 13/14/15): aave_v2, compound_v2, aave_v3.
--   (Compound V3 / Comet can be added later; not required for the core within/across test.)
-- Output: owner, proto, first_supply, tenure_days   (tenure_days = days from first supply to t0)
-- Restricted to each market's pre-shock bal0>=100 universe (keeps the export small, ~13k rows).
-- t0 = 2023-03-09.  USDC = 0xA0b8...eB48 ; cUSDC = 0x39AA...7563.
--
-- Run -> export FULL result (CSV or JSON) -> save as data/tenure.csv -> upload.

WITH
-- ================= Aave V2 (old, pooled) =================
av2_s AS (SELECT "onBehalfOf" AS o, CAST(amount AS double)/1e6 AS a, evt_block_time AS t
          FROM aave_v2_ethereum.LendingPool_evt_Deposit  WHERE reserve = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48),
av2_w AS (SELECT "user"       AS o, CAST(amount AS double)/1e6 AS a, evt_block_time AS t
          FROM aave_v2_ethereum.LendingPool_evt_Withdraw WHERE reserve = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48),
av2_bal AS (SELECT o FROM (SELECT o, a AS s FROM av2_s WHERE t < TIMESTAMP '2023-03-09'
                           UNION ALL SELECT o, -a FROM av2_w WHERE t < TIMESTAMP '2023-03-09') u
            GROUP BY o HAVING SUM(s) >= 100),
av2 AS (SELECT o AS owner, 'aave_v2' AS proto, MIN(t) AS first_supply
        FROM av2_s WHERE t < TIMESTAMP '2023-03-09' AND o IN (SELECT o FROM av2_bal) GROUP BY o),

-- ================= Compound V2 (old, pooled) =================
cv2_s AS (SELECT minter   AS o, CAST("mintAmount"   AS double)/1e6 AS a, evt_block_time AS t
          FROM compound_v2_ethereum.cErc20_evt_Mint   WHERE contract_address = 0x39AA39c021dfbaE8faC545936693aC917d5E7563),
cv2_w AS (SELECT redeemer AS o, CAST("redeemAmount" AS double)/1e6 AS a, evt_block_time AS t
          FROM compound_v2_ethereum.cErc20_evt_Redeem WHERE contract_address = 0x39AA39c021dfbaE8faC545936693aC917d5E7563),
cv2_bal AS (SELECT o FROM (SELECT o, a AS s FROM cv2_s WHERE t < TIMESTAMP '2023-03-09'
                           UNION ALL SELECT o, -a FROM cv2_w WHERE t < TIMESTAMP '2023-03-09') u
            GROUP BY o HAVING SUM(s) >= 100),
cv2 AS (SELECT o AS owner, 'compound_v2' AS proto, MIN(t) AS first_supply
        FROM cv2_s WHERE t < TIMESTAMP '2023-03-09' AND o IN (SELECT o FROM cv2_bal) GROUP BY o),

-- ================= Aave V3 (new, pooled) =================
av3_s AS (SELECT "onBehalfOf" AS o, CAST(amount AS double)/1e6 AS a, evt_block_time AS t
          FROM aave_v3_ethereum.Pool_evt_Supply   WHERE reserve = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48),
av3_w AS (SELECT "user"       AS o, CAST(amount AS double)/1e6 AS a, evt_block_time AS t
          FROM aave_v3_ethereum.Pool_evt_Withdraw WHERE reserve = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48),
av3_bal AS (SELECT o FROM (SELECT o, a AS s FROM av3_s WHERE t < TIMESTAMP '2023-03-09'
                           UNION ALL SELECT o, -a FROM av3_w WHERE t < TIMESTAMP '2023-03-09') u
            GROUP BY o HAVING SUM(s) >= 100),
av3 AS (SELECT o AS owner, 'aave_v3' AS proto, MIN(t) AS first_supply
        FROM av3_s WHERE t < TIMESTAMP '2023-03-09' AND o IN (SELECT o FROM av3_bal) GROUP BY o)

SELECT owner, proto, first_supply,
       date_diff('day', first_supply, TIMESTAMP '2023-03-09') AS tenure_days
FROM (SELECT * FROM av2 UNION ALL SELECT * FROM cv2 UNION ALL SELECT * FROM av3) x
