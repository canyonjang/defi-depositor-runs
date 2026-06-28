-- Welfare baseline: DEX USDC sales by depositors who did NOT run (stayers).
-- Output columns: owner, n_sells, usd_sold, dumped
WITH stayers AS (
  SELECT DISTINCT "onBehalfOf" AS w
  FROM aave_v2_ethereum.LendingPool_evt_Deposit
  WHERE reserve = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 AND evt_block_time < TIMESTAMP '2023-03-09'
    AND "onBehalfOf" NOT IN (
      SELECT "user" FROM aave_v2_ethereum.LendingPool_evt_Withdraw
      WHERE reserve = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
        AND evt_block_time >= TIMESTAMP '2023-03-09' AND evt_block_time < TIMESTAMP '2023-03-15')
)
SELECT st.w AS owner,
  COUNT(t.taker)                              AS n_sells,
  COALESCE(SUM(t.amount_usd),0)               AS usd_sold,
  CASE WHEN COUNT(t.taker) > 0 THEN 1 ELSE 0 END AS dumped
FROM stayers st
LEFT JOIN dex.trades t ON t.taker = st.w AND t.token_sold_address = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
  AND t.blockchain = 'ethereum'
  AND t.block_time >= TIMESTAMP '2023-03-09' AND t.block_time < TIMESTAMP '2023-03-18'
GROUP BY st.w
