-- Welfare (Table 7 / Figure 6): post-withdrawal USDC sales by Aave runners, within 72h.
-- Output columns: owner, wd_time, n_sells_72h, usd_sold_72h, first_sell_time, dumped
WITH runners AS (
  SELECT "user" AS w, MIN(evt_block_time) AS wd_time
  FROM aave_v2_ethereum.LendingPool_evt_Withdraw
  WHERE reserve = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
    AND evt_block_time >= TIMESTAMP '2023-03-09' AND evt_block_time < TIMESTAMP '2023-03-15'
  GROUP BY "user"
),
usdc_sells AS (
  SELECT taker AS w, block_time AS swap_time, amount_usd AS usd
  FROM dex.trades
  WHERE blockchain = 'ethereum'
    AND token_sold_address = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
    AND block_time >= TIMESTAMP '2023-03-09' AND block_time < TIMESTAMP '2023-03-18'
)
SELECT r.w AS owner, r.wd_time,
  COUNT(s.w)                                 AS n_sells_72h,
  COALESCE(SUM(s.usd),0)                      AS usd_sold_72h,
  MIN(s.swap_time)                            AS first_sell_time,
  CASE WHEN COUNT(s.w) > 0 THEN 1 ELSE 0 END  AS dumped
FROM runners r
LEFT JOIN usdc_sells s ON s.w = r.w
  AND s.swap_time >= r.wd_time AND s.swap_time < r.wd_time + INTERVAL '72' HOUR
GROUP BY r.w, r.wd_time ORDER BY usd_sold_72h DESC
