-- Figure 4 (herding): distinct withdrawing wallets per hour, Aave V2 USDC, around the depeg.
-- Output columns: hour, n_withdraws, n_wd_wallets, outflow_usdc
SELECT date_trunc('hour', evt_block_time) AS hour,
       COUNT(*)                              AS n_withdraws,
       COUNT(DISTINCT "user")                AS n_wd_wallets,
       SUM(CAST(amount AS double)/1e6)       AS outflow_usdc
FROM aave_v2_ethereum.LendingPool_evt_Withdraw
WHERE reserve = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
  AND evt_block_time >= TIMESTAMP '2023-02-20'
  AND evt_block_time <  TIMESTAMP '2023-03-20'
GROUP BY 1
ORDER BY 1
