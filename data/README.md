# Data dictionary and provenance

All files are CSV extracts of public Ethereum on-chain records, obtained via Dune Analytics.
Each file is produced by the correspondingly named SQL query in `../queries/`.

| CSV file | source query | rows | description |
|---|---|---|---|
| `aave_usdc_daily_flows.csv`     | 01 | daily   | Aave V2 USDC daily deposit/withdraw flows |
| `compound_usdc_daily_flows.csv` | 02 | daily   | Compound V3 USDC daily flows |
| `aave_usdc_hourly_herding.csv`  | 03 | hourly  | Aave V2 USDC distinct withdrawing wallets per hour |
| `aave_usdc_panel.csv`           | 04 | wallet  | Aave V2 USDC depositor cross-section (primary) |
| `aave_usdc_placebo.csv`         | 05 | wallet  | Aave V2 USDC pre-event placebo windows (DiD) |
| `compound_usdc_panel.csv`       | 06 | wallet  | Compound V3 USDC depositor cross-section |
| `compound_usdc_top30.csv`       | 07 | wallet  | 30 largest Compound USDC depositors (contamination) |
| `aave_usdt_2023_panel.csv`      | 08 | wallet  | Aave V2 USDT depositor cross-section, 2023 episode |
| `aave_usdt_2022_panel.csv`      | 09 | wallet  | Aave V2 USDT depositor cross-section, 2022 Terra episode |
| `welfare_runner_sells.csv`      | 10 | wallet  | Runners' post-withdrawal USDC DEX sales (<=72h) |
| `usdc_minute_price.csv`         | 11 | minute  | USDC minute-level price across the depeg trough |
| `welfare_stayer_sells.csv`      | 12 | wallet  | Stayers' USDC DEX sales (welfare baseline) |

## Column dictionary (depositor panels: aave_usdc_panel, compound_usdc_panel, aave_usdt_*)

- `owner`           — depositor wallet address (the `onBehalfOf` of Aave deposits / Comet `dst`)
- `bal0`            — pre-shock net USDC (or USDT) supplied to the reserve, in token units
- `tx_sent_count`   — number of externally-originated transactions before t0 (activity / sophistication proxy; 0 ⇒ smart contract)
- `wallet_age_days` — days between the wallet's first transaction and t0
- `ran`             — 1 if the wallet withdrew during the 6-day event window, else 0
- `first_wd_hours`  — hours from t0 to the wallet's first event-window withdrawal (blank if it did not run)
- `wd_win`          — total amount withdrawn during the event window

## Other files

- daily flows: `day, inflow_usdc, outflow_usdc, net_usdc, n_deposits, n_withdraws, n_dep_users, n_wd_users`
- hourly herding: `hour, n_withdraws, n_wd_wallets, outflow_usdc`
- placebo: `owner, ran_p1, ran_p2, ran_p3` (ran indicator in each of three Feb-2023 windows)
- welfare_runner_sells: `owner, wd_time, n_sells_72h, usd_sold_72h, first_sell_time, dumped`
- usdc_minute_price: `ts, price`
- welfare_stayer_sells: `owner, n_sells, usd_sold, dumped`

Individually-operated depositors are those with `tx_sent_count > 0` and `bal0 >= 100`.
