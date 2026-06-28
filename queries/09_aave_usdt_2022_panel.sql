-- External validity (cell 4): Aave V2 USDT reserve, May 2022 Terra/LUNA episode. t0 = 2022-05-09.
-- Identical to query 08 with the event window shifted to May 2022.
-- Output columns: owner, bal0, tx_sent_count, wallet_age_days, ran, first_wd_hours, wd_win
WITH
dep AS (SELECT "onBehalfOf" AS owner, CAST(amount AS double)/1e6 AS amt, evt_block_time AS ts
        FROM aave_v2_ethereum.LendingPool_evt_Deposit  WHERE reserve = 0xdAC17F958D2ee523a2206206994597C13D831ec7),
wdr AS (SELECT "user" AS owner, CAST(amount AS double)/1e6 AS amt, evt_block_time AS ts
        FROM aave_v2_ethereum.LendingPool_evt_Withdraw WHERE reserve = 0xdAC17F958D2ee523a2206206994597C13D831ec7),
bal AS (SELECT owner, SUM(s) AS bal0 FROM (
          SELECT owner, amt AS s FROM dep WHERE ts < TIMESTAMP '2022-05-09'
          UNION ALL SELECT owner, -amt FROM wdr WHERE ts < TIMESTAMP '2022-05-09') GROUP BY owner),
runs AS (SELECT owner, MIN(ts) AS first_wd_time, SUM(amt) AS wd_win FROM wdr
         WHERE ts >= TIMESTAMP '2022-05-09' AND ts < TIMESTAMP '2022-05-15' GROUP BY owner),
soph AS (SELECT "from" AS owner, COUNT(*) AS tx_sent_count, MIN(block_time) AS first_tx_time
         FROM ethereum.transactions WHERE block_time < TIMESTAMP '2022-05-09'
           AND "from" IN (SELECT owner FROM bal) GROUP BY "from")
SELECT b.owner, b.bal0, COALESCE(s.tx_sent_count,0) AS tx_sent_count,
  date_diff('day', s.first_tx_time, TIMESTAMP '2022-05-09') AS wallet_age_days,
  CASE WHEN r.owner IS NOT NULL THEN 1 ELSE 0 END AS ran,
  date_diff('hour', TIMESTAMP '2022-05-09', r.first_wd_time) AS first_wd_hours,
  COALESCE(r.wd_win,0) AS wd_win
FROM bal b LEFT JOIN runs r ON r.owner=b.owner LEFT JOIN soph s ON s.owner=b.owner
WHERE b.bal0 > 0 ORDER BY b.bal0 DESC
