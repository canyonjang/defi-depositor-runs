# Replication package — "Who Runs First? The Microstructure of Depositor Runs in DeFi Lending"

This repository reproduces all empirical results, tables, and figures in the paper
*Who Runs First? The Microstructure of Depositor Runs in DeFi Lending: Wallet-Level
Evidence from the USDC Depeg.*

All underlying data are public Ethereum on-chain records. The panels were extracted with
SQL on [Dune Analytics](https://dune.com), which exposes decoded protocol event logs
(e.g. `aave_v2_ethereum.LendingPool_evt_Withdraw`). The same series can be rebuilt from
the raw logs in the `bigquery-public-data.crypto_ethereum` public dataset by decoding the
corresponding events.

## What is here

```
defi-depositor-runs/
├── queries/   12 Dune SQL queries, one per data extract (see headers for outputs)
├── data/      the 12 extracts as CSV  (+ data/README.md: column dictionary & provenance)
├── code/      reproduce_tables.py, reproduce_figures.py
├── requirements.txt
├── CITATION.cff
└── LICENSE
```

## Reproduce in two commands

```bash
pip install -r requirements.txt
cd code
python reproduce_tables.py     # prints Table 5 cells, event-study sigma, herding, welfare
python reproduce_figures.py    # writes Figures 1-6 (vector PDF + 300 dpi PNG) to code/figures/
```

No internet or API key is required: the scripts read the CSVs in `data/`.
The logit (Newton-Raphson) and Cox proportional-hazards (partial-likelihood) estimators are
hand-coded in NumPy/SciPy, so `statsmodels`/`lifelines` are **not** needed.

## Re-extracting the data from scratch (optional)

Open each file in `queries/` on Dune, run it, and export the result as CSV into `data/`
under the filename given in `data/README.md`. The queries are dialect-portable Trino/DuneSQL.
Key addresses: USDC `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48`,
USDT `0xdAC17F958D2ee523a2206206994597C13D831ec7`,
Compound III (Comet) USDC `0xc3d688B66703497DAA19211EEdff47f25384cdc3`.
Event onset t0 = 2023-03-09 (USDC/SVB episodes) and 2022-05-09 (USDT/Terra episode).

## Notes

- `aave_usdc_daily_flows.csv` and `compound_usdc_daily_flows.csv` were exported with a
  1,000-row cap that fully covers the event window used in the paper.
- Reported figures may differ from the scripts' output in the last decimal due to rounding.

## Citation

See `CITATION.cff`. If you use this package, please cite the paper and this repository.
