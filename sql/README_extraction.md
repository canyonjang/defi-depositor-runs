# On-chain extraction (Dune Analytics)

All series were extracted from decoded Ethereum event logs on Dune Analytics
(the same data can be rebuilt from `bigquery-public-data.crypto_ethereum`).
Numbered queries in this folder produce the CSV extracts in `../data/`.

Contract / event tables used:
- Aave V2   : aave_v2_ethereum.LendingPool_evt_Deposit (onBehalfOf) / _Withdraw (user), reserve = USDC
- Aave V3   : aave_v3_ethereum.Pool_evt_Supply (onBehalfOf) / _Withdraw (user), reserve = USDC
- Compound V2: compound_v2_ethereum.cErc20_evt_Mint (minter) / _Redeem (redeemer), contract = cUSDC
- Compound V3: compound_v3_ethereum.cusdcv3_evt_supply (dst) / _withdraw (src) / _transfer (from/to)
- Receipt tokens: aUSDC 0xBcca60bB61934080951369a648Fb03DF4F96263C,
  aEthUSDC 0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c,
  cUSDC 0x39AA39c021dfbaE8faC545936693aC917d5E7563,
  cUSDCv3 0xc3d688B66703497DAA19211EEdff47f25384cdc3
- USDC 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
- Event window: t0 = 2023-03-09 00:00 UTC; run window [t0, t0+144h); baseline 2023-01-08..03-08.

The four wallet panels (bal0, ran, first_wd_hours, wallet_age_days, tx_sent_count)
and the two daily reserve-flow series are built from the Deposit/Withdraw (Mint/Redeem)
events above joined to wallet transaction history; the resulting CSV extracts are
provided directly in ../data/ so the analysis reproduces without Dune access.
Queries 13-20 provide the tenure, run-magnitude, and receipt-token reconstruction steps.
