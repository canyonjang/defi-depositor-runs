# Data dictionary

Wallet panels (one row per individually operated depositor):
  aave_usdc_panel.csv, compound_v2_usdc_panel.csv, aave_v3_usdc_panel.csv, compound_usdc_panel.csv
    owner            wallet address (lower-case hex)
    bal0             event-based pre-shock USDC balance (cumulative supply - withdrawal)
    ran              1 if the wallet withdrew any USDC in [t0, t0+144h)
    first_wd_hours   hours from t0 to first withdrawal (blank if none)
    tx_sent_count    lifetime outgoing tx count (activity)
    wallet_age_days  age of the wallet at t0

Reconstruction inputs:
  tenure4.csv        owner, proto, tenure_days   (days from first USDC supply to t0; four markets)
  net_usdc.csv       owner, market, net_usdc     (net receipt-token transfer converted to USDC)
  receipt_netflows.csv  owner, market, recv, sent (raw receipt-token in/out, native units)  [query 20]
  receipt_transfers.csv owner, market, role       (wallets that transferred receipt tokens) [query 19]
  run_magnitude.csv  owner, market, ev_out, ev_in, pl_out (event-window & placebo flows)   [query 18]
  aave_usdc_borrowers.csv owner, ever_borrowed, ... (for the leverage-unwinding robustness) [query 13]

Aggregate series:
  aave_usdc_daily_flows.csv, compound_usdc_daily_flows.csv  day, outflow_usdc, net_usdc
  usdc_minute_price.csv  ts, price   (for the event-onset robustness)

Reconstructed main sample used in the paper:
  keep wallets with tx_sent_count>0 and bal0>=100; corr_bal0 = bal0 + net_usdc; then keep corr_bal0>=100.
  This is done inside code/reproduce.py.
