"""
Reproduce the key numerical results of the paper from the CSV extracts in ../data/.
No internet required. Hand-coded logit (Newton-Raphson) and Cox partial-likelihood,
so only numpy / scipy / pandas are needed (no statsmodels / lifelines).

Run:  python reproduce_tables.py
"""
import numpy as np, pandas as pd
from scipy.stats import spearmanr
from scipy.optimize import minimize
D = "../data/"

def zscore(x): return (x - x.mean()) / x.std()

def logit(X, y, ridge=1e-6):
    X = np.column_stack([np.ones(len(X)), X]); k = X.shape[1]; b = np.zeros(k)
    for _ in range(200):
        p = 1/(1+np.exp(-(X@b))); W = p*(1-p)
        H = -(X*W[:,None]).T@X - ridge*np.eye(k); g = X.T@(y-p) - ridge*b
        step = np.linalg.solve(H, g); b -= step
        if np.max(np.abs(step)) < 1e-9: break
    se = np.sqrt(np.diag(np.linalg.inv(-H))); return b, b/se

def cox(X, T, ev):
    def negll(beta):
        eta = X@beta; w = np.exp(eta); order = np.argsort(-T)
        Ts, ws, Xo, evo = T[order], w[order], X[order], ev[order]
        cw = np.cumsum(ws); cwx = np.cumsum(ws[:,None]*Xo, 0)
        last = {tt:i for i,tt in enumerate(Ts)}; ll = 0.0; g = np.zeros(X.shape[1])
        for tt in np.unique(Ts):
            i = last[tt]; de = (Ts==tt)&(evo==1); d = de.sum()
            if d==0: continue
            sx = Xo[de].sum(0); ll += sx@beta - d*np.log(cw[i]); g += sx - d*(cwx[i]/cw[i])
        return -ll, -g
    r = minimize(lambda b: negll(b)[0], np.zeros(X.shape[1]),
                 jac=lambda b: negll(b)[1], method="BFGS")
    be = r.x; eps = 1e-5; H = np.zeros((X.shape[1],)*2)
    for j in range(X.shape[1]):
        bp = be.copy(); bp[j]+=eps; bm = be.copy(); bm[j]-=eps
        H[:,j] = (negll(bp)[1]-negll(bm)[1])/(2*eps)
    se = np.sqrt(np.diag(np.linalg.inv(H))); return be, be/se

def analyze_cell(csv, label, t0_hours_window=144.0):
    df = pd.read_csv(D+csv)
    bal = df["bal0"].to_numpy(float); tx = df["tx_sent_count"].to_numpy(float)
    ran = df["ran"].to_numpy(float)
    age = pd.to_numeric(df["wallet_age_days"], errors="coerce").to_numpy(float)
    fwh = pd.to_numeric(df["first_wd_hours"], errors="coerce").to_numpy(float)
    print("\n===== %s =====" % label)
    # deciles on individually-operated depositors (activity>0, balance >= $100)
    m = (tx>0) & (bal>=100); b, rn, fw = bal[m], ran[m], fwh[m]
    o = np.argsort(b, kind="mergesort"); b, rn, fw = b[o], rn[o], fw[o]
    idx = np.array_split(np.arange(len(b)), 10)
    Wd = [rn[ix].mean()*100 for ix in idx]
    rs  = spearmanr(np.arange(1,11), Wd); rs9 = spearmanr(np.arange(1,10), Wd[:9])
    print(f"  N_individual={m.sum()}  runners={int(rn.sum())}")
    print(f"  withdrawal rate by decile (%): {[round(w,2) for w in Wd]}")
    print(f"  rho_S = {rs.statistic:.3f} (p={rs.pvalue:.2g}) | D1-D9 = {rs9.statistic:.3f}")
    # wallet-level logit + Cox (standardized covariates)
    mr = (tx>0) & (bal>=1) & ~np.isnan(age)
    X = np.column_stack([zscore(np.log10(bal[mr])),
                         zscore(np.log10(tx[mr]+1)),
                         zscore(np.log10(age[mr]+1))])
    yb = ran[mr]; bb, zb = logit(X, yb)
    print(f"  [LOGIT] N={mr.sum()} events={int(yb.sum())} | "
          f"size OR={np.exp(bb[1]):.2f} (z={zb[1]:.1f}) | "
          f"soph OR={np.exp(bb[2]):.2f} (z={zb[2]:.1f}) | "
          f"age OR={np.exp(bb[3]):.2f} (z={zb[3]:.1f})")
    T = np.where(yb==1, np.maximum(fwh[mr], 0.5), t0_hours_window)
    be, zc = cox(X, T, yb)
    print(f"  [COX]   size HR={np.exp(be[0]):.2f} (z={zc[0]:.1f}) | "
          f"soph HR={np.exp(be[1]):.2f} (z={zc[1]:.1f}) | "
          f"age HR={np.exp(be[2]):.2f} (z={zc[2]:.1f})")

if __name__ == "__main__":
    print("="*64)
    print("TABLE 5 — replication across protocols, assets, and shocks")
    print("="*64)
    analyze_cell("aave_usdc_panel.csv",     "Aave V2 . USDC . 2023 (SVB)")
    analyze_cell("compound_usdc_panel.csv", "Compound V3 . USDC . 2023 (SVB)")
    analyze_cell("aave_usdt_2023_panel.csv","Aave V2 . USDT . 2023 (SVB contagion)")
    analyze_cell("aave_usdt_2022_panel.csv","Aave V2 . USDT . 2022 (Terra collapse)")

    # ---- Event-study peak sigma (Table 5 / Figure 1) ----
    print("\n" + "="*64); print("EVENT STUDY — peak standardized abnormal outflow")
    for csv, lab in [("aave_usdc_daily_flows.csv","Aave V2"),
                     ("compound_usdc_daily_flows.csv","Compound V3")]:
        d = pd.read_csv(D+csv); d["day"] = pd.to_datetime(d["day"])
        base = d[(d.day>="2023-01-08") & (d.day<="2023-03-08")]["outflow_usdc"]
        mu, sd = base.mean(), base.std(ddof=0)
        peak = d[d.day=="2023-03-11"]["outflow_usdc"]
        if len(peak): print(f"  {lab}: peak {(peak.iloc[0]-mu)/sd:+.1f} sigma on 2023-03-11")

    # ---- Herding (Table / Figure 4) ----
    print("\n" + "="*64); print("HERDING — hourly concurrency")
    h = pd.read_csv(D+"aave_usdc_hourly_herding.csv"); h["hour"]=pd.to_datetime(h["hour"])
    base = h[h.hour<"2023-03-09"]["n_wd_wallets"]
    mu, sd, mx = base.mean(), base.std(ddof=0), base.max()
    peak = h["n_wd_wallets"].max()
    print(f"  baseline mean={mu:.2f}, sd={sd:.2f}, max={int(mx)}")
    print(f"  acute peak={int(peak)} wallets/h = {(peak-mu)/sd:+.1f} sigma; normal max={int(mx)}")

    # ---- Welfare (Table 7 / Figure 6) ----
    print("\n" + "="*64); print("WELFARE — loss realization")
    rs = pd.read_csv(D+"welfare_runner_sells.csv"); ss = pd.read_csv(D+"welfare_stayer_sells.csv")
    print(f"  runners dumped: {rs['dumped'].mean()*100:.1f}%  (N={len(rs)})")
    print(f"  stayers dumped: {ss['dumped'].mean()*100:.1f}%  (N={len(ss)})")
    print("\nDone. See reproduce_figures.py to regenerate Figures 1-6.")
