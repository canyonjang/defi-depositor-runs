-- query 20b: receipt-token NET transfers, RESTRICTED to the supplier (panel) universe so the
-- result fits the free 32k JSON export (~21k rows). Reconstruction goal:
--   corrected_bal0 = panel_bal0(USDC) + (recv - sent) converted to USDC.
-- Only wallets in the panel universe (net USDC supplied >= 100 before t0) are returned; this
-- captures the dominant distortion (PHANTOM holders that supplied then transferred the receipt
-- token away). Pure received-only wallets that never supplied are outside the sample (noted limit).
--
-- Output: owner, market, recv, sent  (native receipt-token units; net = recv - sent).
-- Convert in Python: aave_v2/aave_v3/compound_v3 -> /1e6 USDC ; compound_v2 -> /1e8 * 0.0228 USDC.
-- Run -> export JSON -> save as data/receipt_netflows.csv -> upload.
-- (If compound_v3 Transfer errors, tell me the columns of compound_v3_ethereum.cusdcv3_evt_transfer.)

WITH
u_av2 AS (
  SELECT o FROM (
    SELECT "onBehalfOf" o, CAST(amount AS double)/1e6 s FROM aave_v2_ethereum.LendingPool_evt_Deposit
      WHERE reserve=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 AND evt_block_time<TIMESTAMP '2023-03-09'
    UNION ALL
    SELECT "user", -CAST(amount AS double)/1e6 FROM aave_v2_ethereum.LendingPool_evt_Withdraw
      WHERE reserve=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 AND evt_block_time<TIMESTAMP '2023-03-09'
  ) g GROUP BY o HAVING SUM(s)>=100
),
u_cv2 AS (
  SELECT o FROM (
    SELECT minter o, CAST("mintAmount" AS double)/1e6 s FROM compound_v2_ethereum.cErc20_evt_Mint
      WHERE contract_address=0x39AA39c021dfbaE8faC545936693aC917d5E7563 AND evt_block_time<TIMESTAMP '2023-03-09'
    UNION ALL
    SELECT redeemer, -CAST("redeemAmount" AS double)/1e6 FROM compound_v2_ethereum.cErc20_evt_Redeem
      WHERE contract_address=0x39AA39c021dfbaE8faC545936693aC917d5E7563 AND evt_block_time<TIMESTAMP '2023-03-09'
  ) g GROUP BY o HAVING SUM(s)>=100
),
u_av3 AS (
  SELECT o FROM (
    SELECT "onBehalfOf" o, CAST(amount AS double)/1e6 s FROM aave_v3_ethereum.Pool_evt_Supply
      WHERE reserve=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 AND evt_block_time<TIMESTAMP '2023-03-09'
    UNION ALL
    SELECT "user", -CAST(amount AS double)/1e6 FROM aave_v3_ethereum.Pool_evt_Withdraw
      WHERE reserve=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 AND evt_block_time<TIMESTAMP '2023-03-09'
  ) g GROUP BY o HAVING SUM(s)>=100
),
u_cv3 AS (
  SELECT o FROM (
    SELECT dst o, CAST(amount AS double)/1e6 s FROM compound_v3_ethereum.cusdcv3_evt_supply
      WHERE evt_block_time<TIMESTAMP '2023-03-09'
    UNION ALL
    SELECT src, -CAST(amount AS double)/1e6 FROM compound_v3_ethereum.cusdcv3_evt_withdraw
      WHERE evt_block_time<TIMESTAMP '2023-03-09'
  ) g GROUP BY o HAVING SUM(s)>=100
),
tr AS (
  SELECT to w, CAST(value AS double) a, 'aave_v2' m, 'in' d FROM erc20_ethereum.evt_Transfer
    WHERE contract_address=0xBcca60bB61934080951369a648Fb03DF4F96263C AND evt_block_time<TIMESTAMP '2023-03-09'
      AND "from"!=0x0000000000000000000000000000000000000000 AND to IN (SELECT o FROM u_av2)
  UNION ALL
  SELECT "from", CAST(value AS double), 'aave_v2','out' FROM erc20_ethereum.evt_Transfer
    WHERE contract_address=0xBcca60bB61934080951369a648Fb03DF4F96263C AND evt_block_time<TIMESTAMP '2023-03-09'
      AND to!=0x0000000000000000000000000000000000000000 AND "from" IN (SELECT o FROM u_av2)
  UNION ALL
  SELECT to, CAST(value AS double), 'aave_v3','in' FROM erc20_ethereum.evt_Transfer
    WHERE contract_address=0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c AND evt_block_time<TIMESTAMP '2023-03-09'
      AND "from"!=0x0000000000000000000000000000000000000000 AND to IN (SELECT o FROM u_av3)
  UNION ALL
  SELECT "from", CAST(value AS double), 'aave_v3','out' FROM erc20_ethereum.evt_Transfer
    WHERE contract_address=0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c AND evt_block_time<TIMESTAMP '2023-03-09'
      AND to!=0x0000000000000000000000000000000000000000 AND "from" IN (SELECT o FROM u_av3)
  UNION ALL
  SELECT to, CAST(value AS double), 'compound_v2','in' FROM erc20_ethereum.evt_Transfer
    WHERE contract_address=0x39AA39c021dfbaE8faC545936693aC917d5E7563 AND evt_block_time<TIMESTAMP '2023-03-09'
      AND "from"!=0x0000000000000000000000000000000000000000 AND to IN (SELECT o FROM u_cv2)
  UNION ALL
  SELECT "from", CAST(value AS double), 'compound_v2','out' FROM erc20_ethereum.evt_Transfer
    WHERE contract_address=0x39AA39c021dfbaE8faC545936693aC917d5E7563 AND evt_block_time<TIMESTAMP '2023-03-09'
      AND to!=0x0000000000000000000000000000000000000000 AND "from" IN (SELECT o FROM u_cv2)
  UNION ALL
  SELECT to, CAST(amount AS double), 'compound_v3','in' FROM compound_v3_ethereum.cusdcv3_evt_transfer
    WHERE evt_block_time<TIMESTAMP '2023-03-09'
      AND "from"!=0x0000000000000000000000000000000000000000 AND to IN (SELECT o FROM u_cv3)
  UNION ALL
  SELECT "from", CAST(amount AS double), 'compound_v3','out' FROM compound_v3_ethereum.cusdcv3_evt_transfer
    WHERE evt_block_time<TIMESTAMP '2023-03-09'
      AND to!=0x0000000000000000000000000000000000000000 AND "from" IN (SELECT o FROM u_cv3)
)
SELECT w AS owner, m AS market,
       SUM(CASE WHEN d='in'  THEN a ELSE 0 END) AS recv,
       SUM(CASE WHEN d='out' THEN a ELSE 0 END) AS sent
FROM tr
GROUP BY w, m
