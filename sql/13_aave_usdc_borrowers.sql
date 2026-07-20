-- query 13 (v2, panel-scoped): borrower flag for the Aave V2 USDC depositor panel ONLY.
-- Fixes the 32k API pagination cap: instead of listing all ~52k Aave borrowers, it returns
-- exactly one row per USDC depositor in the panel (~10k rows, single page, directly mergeable).
-- t0 = 2023-03-09.  Output: owner, ever_borrowed, n_borrow, n_repay, net_open
--   ever_borrowed = 1 if the wallet took on any Aave V2 debt (ANY reserve) before t0.
--   net_open      = n_borrow - n_repay (coarse "open position" indicator).
-- For the headline robustness check (Appendix Table A.3) restrict to ever_borrowed = 0.
--
-- Usage: run on Dune, export the FULL result (CSV or JSON), upload it back.
WITH
dep AS (
  SELECT "onBehalfOf" AS owner, CAST(amount AS double)/1e6 AS amt, evt_block_time AS ts
  FROM aave_v2_ethereum.LendingPool_evt_Deposit  WHERE reserve = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
),
wdr AS (
  SELECT "user" AS owner, CAST(amount AS double)/1e6 AS amt, evt_block_time AS ts
  FROM aave_v2_ethereum.LendingPool_evt_Withdraw WHERE reserve = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
),
bal AS (  -- the panel universe: USDC depositors with positive pre-t0 balance (matches query 04)
  SELECT owner FROM (
    SELECT owner,  amt AS s FROM dep WHERE ts < TIMESTAMP '2023-03-09'
    UNION ALL
    SELECT owner, -amt AS s FROM wdr WHERE ts < TIMESTAMP '2023-03-09'
  ) GROUP BY owner HAVING SUM(s) > 0
),
borrows AS (
  SELECT "onBehalfOf" AS owner, COUNT(*) AS n_borrow
  FROM aave_v2_ethereum.LendingPool_evt_Borrow
  WHERE evt_block_time < TIMESTAMP '2023-03-09' AND "onBehalfOf" IN (SELECT owner FROM bal)
  GROUP BY "onBehalfOf"
),
repays AS (
  SELECT "user" AS owner, COUNT(*) AS n_repay
  FROM aave_v2_ethereum.LendingPool_evt_Repay
  WHERE evt_block_time < TIMESTAMP '2023-03-09' AND "user" IN (SELECT owner FROM bal)
  GROUP BY "user"
)
SELECT
  p.owner,
  CASE WHEN b.owner IS NOT NULL THEN 1 ELSE 0 END   AS ever_borrowed,
  COALESCE(b.n_borrow, 0)                            AS n_borrow,
  COALESCE(r.n_repay, 0)                             AS n_repay,
  COALESCE(b.n_borrow, 0) - COALESCE(r.n_repay, 0)   AS net_open
FROM bal p
LEFT JOIN borrows b ON b.owner = p.owner
LEFT JOIN repays  r ON r.owner = p.owner
