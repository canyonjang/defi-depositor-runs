-- Difference-in-differences baseline: withdrawal in three length-matched pre-event placebo windows.
-- Output columns: owner, ran_p1, ran_p2, ran_p3
WITH withdraws AS (
  SELECT "user" AS owner, evt_block_time AS ts
  FROM aave_v2_ethereum.LendingPool_evt_Withdraw
  WHERE reserve = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
    AND evt_block_time >= TIMESTAMP '2023-02-01' AND evt_block_time < TIMESTAMP '2023-03-03'
)
SELECT owner,
  MAX(CASE WHEN ts <  TIMESTAMP '2023-02-07' THEN 1 ELSE 0 END) AS ran_p1,
  MAX(CASE WHEN ts >= TIMESTAMP '2023-02-13' AND ts < TIMESTAMP '2023-02-19' THEN 1 ELSE 0 END) AS ran_p2,
  MAX(CASE WHEN ts >= TIMESTAMP '2023-02-25' THEN 1 ELSE 0 END) AS ran_p3
FROM withdraws GROUP BY owner
