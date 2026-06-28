-- Figure 1 / event study: daily flows, Compound V3 (Comet) USDC market.
-- Output columns: day, inflow_usdc, outflow_usdc, net_usdc, n_deposits, n_withdraws, n_dep_users, n_wd_users
WITH d AS (
  SELECT date_trunc('day', evt_block_time) AS day, CAST(amount AS double)/1e6 AS amt, dst AS u, 'dep' AS kind
  FROM compound_v3_ethereum.cUSDCv3_evt_Supply
  UNION ALL
  SELECT date_trunc('day', evt_block_time), CAST(amount AS double)/1e6, src, 'wd'
  FROM compound_v3_ethereum.cUSDCv3_evt_Withdraw
)
SELECT day,
  SUM(CASE WHEN kind='dep' THEN amt ELSE 0 END)    AS inflow_usdc,
  SUM(CASE WHEN kind='wd'  THEN amt ELSE 0 END)    AS outflow_usdc,
  SUM(CASE WHEN kind='dep' THEN amt ELSE -amt END) AS net_usdc,
  COUNT(CASE WHEN kind='dep' THEN 1 END)           AS n_deposits,
  COUNT(CASE WHEN kind='wd'  THEN 1 END)           AS n_withdraws,
  COUNT(DISTINCT CASE WHEN kind='dep' THEN u END)  AS n_dep_users,
  COUNT(DISTINCT CASE WHEN kind='wd'  THEN u END)  AS n_wd_users
FROM d
GROUP BY day
ORDER BY day
