# Replication package

**Deposit tenure and run participation in decentralized lending: Wallet-level evidence from the 2023 USDC de-peg**

This package reproduces every number in Tables 1–3 and Figures 1–3 of the paper
from public Ethereum on-chain data.

## Contents
- `code/reproduce.py` — single script; prints Tables 1–3 and writes Figures 1–3.
- `data/` — CSV extracts (see `data/DATA_DICTIONARY.md`).
- `sql/` — Dune Analytics extraction queries (see `sql/README_extraction.md`).
- `figures/` — the figure PDFs as they appear in the paper.
- `requirements.txt` — Python dependencies.

## How to reproduce
```bash
pip install -r requirements.txt
cd code
python reproduce.py
```
This prints the reconstructed-sample results (Table 2: size OR 2.82, tenure OR 0.47,
N = 7,848; Table 1: 4.17× vs 1.46× intensity gap; Table 3: tenure-band withdrawal rates)
and regenerates `figures/Figure_1_intensity.pdf`, `Figure_2_tenure.pdf`, `Figure_3_size.pdf`.

## Data and method
All data are public Ethereum records extracted via Dune Analytics from decoded protocol
event logs (Aave V2/V3, Compound V2/V3 USDC markets) around the March 2023 USDC de-peg.
Pre-shock balances are reconstructed direct holdings: event-based supply-minus-withdrawal
balances adjusted for net receipt-token (aToken/cToken) transfers before the shock.
See `sql/README_extraction.md` and `data/DATA_DICTIONARY.md` for details.

## License
Data derive from public blockchain records. Code released under the MIT License.

## Citation
Jang, K. (2026). Deposit tenure and run participation in decentralized lending:
Wallet-level evidence from the 2023 USDC de-peg. Working paper.
