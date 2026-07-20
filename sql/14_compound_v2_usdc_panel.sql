-- query 14: Compound V2 (cUSDC) depositor panel — within-issuer architecture contrast.
-- Compound V2 cUSDC = pooled, collateral-integrated market (structurally like Aave V2).
-- Compound V3 USDC  = isolated single base-asset lending market.
-- Same issuer/brand/token => controls trust & vintage; varies ONLY the architecture.
-- Goal: test whether the participation gap tracks the base-asset architecture (V3) rather
--       than "Compound-ness". If V2 participation ~ Aave and only V3 is high, the gap is
--       design-DRIVEN, not merely design-associated.
--
-- Output columns are matched to the shipped panels so the CSV merges directly:
--   owner, bal0, tx_sent_count, wallet_age_days, ran, first_wd_hours
--
-- Conventions (inferred from the shipped panels; DO NOT change — kept identical for merge):
--   t0 / onset  = 2023-03-09 00:00:00 UTC   (pre-shock balance cutoff AND run-clock zero)
--   run window  = [t0, t0 + 144h) = up to 2023-03-15 00:00 UTC (6 days; matches max first_wd_hours=142)
--   amounts in underlying USDC (6 decimals)
--   tx_sent_count / wallet_age_days computed from ethereum.transactions, before t0
--
-- cUSDC (Compound V2): 0x39AA39c021dfbaE8faC545936693aC917d5E7563
--
-- >>> Dune table-name check (do this once before running):
--     This uses the decoded Compound V2 cToken event tables:
--        compound_v2_ethereum.cErc20_evt_Mint    (columns: minter, "mintAmount", ...)
--        compound_v2_ethereum.cErc20_evt_Redeem  (columns: redeemer, "redeemAmount", ...)
--     If those names don't resolve, open Dune's schema browser, search "compound_v2",
--     and use the decoded Mint/Redeem tables (Mint => supply, Redeem => withdraw).
--     Column names may need double-quotes if mixed-case (as with "mintAmount").
--
-- Run on Dune -> export the FULL result as CSV -> save as data/compound_v2_usdc_panel.csv -> upload.

WITH
supply AS (   -- USDC supplied (underlying)
  SELECT minter AS owner,
         CAST("mintAmount" AS double)/1e6 AS amt,
         evt_block_time AS ts
  FROM compound_v2_ethereum.cErc20_evt_Mint
  WHERE contract_address = 0x39AA39c021dfbaE8faC545936693aC917d5E7563
),
redeem AS (   -- USDC withdrawn (underlying)
  SELECT redeemer AS owner,
         CAST("redeemAmount" AS double)/1e6 AS amt,
         evt_block_time AS ts
  FROM compound_v2_ethereum.cErc20_evt_Redeem
  WHERE contract_address = 0x39AA39c021dfbaE8faC545936693aC917d5E7563
),

-- panel universe: net USDC supplied > 0 immediately before t0.  bal0 = pre-shock balance.
bal AS (
  SELECT owner, SUM(s) AS bal0
  FROM (
      SELECT owner,  amt AS s FROM supply WHERE ts < TIMESTAMP '2023-03-09'
      UNION ALL
      SELECT owner, -amt AS s FROM redeem WHERE ts < TIMESTAMP '2023-03-09'
  ) u
  GROUP BY owner
  HAVING SUM(s) > 0
),

-- first withdrawal inside the 6-day run window => run flag + timing
runs AS (
  SELECT owner, MIN(ts) AS first_wd
  FROM redeem
  WHERE ts >= TIMESTAMP '2023-03-09'
    AND ts <  TIMESTAMP '2023-03-09' + INTERVAL '144' HOUR
    AND owner IN (SELECT owner FROM bal)
  GROUP BY owner
),

-- wallet-level activity & age (protocol-independent; same construction as the other panels)
tx AS (
  SELECT "from" AS owner,
         COUNT(*)        AS tx_sent_count,
         MIN(block_time) AS first_tx
  FROM ethereum.transactions
  WHERE block_time < TIMESTAMP '2023-03-09'
    AND "from" IN (SELECT owner FROM bal)
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

-- OPTIONAL (only if we later want the pure-supplier robustness on V2 too):
--   build a V2 borrower flag from compound_v2_ethereum.cErc20_evt_Borrow on the SAME cUSDC
--   address (borrower column), analogous to query 13. Not needed for the participation test.
