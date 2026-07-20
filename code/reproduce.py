"""
Reproduction script for:
  "Deposit tenure and run participation in decentralized lending:
   Wallet-level evidence from the 2023 USDC de-peg"

Reproduces the numbers in Tables 1-3 and Figures 1-3 from the CSV extracts in
../data/.  Run:  python reproduce.py
Requires numpy, pandas, scipy, matplotlib (see ../requirements.txt).
"""
import numpy as np, pandas as pd, matplotlib, math, os
matplotlib.use("Agg"); import matplotlib.pyplot as plt
from scipy.stats import spearmanr
plt.rcParams.update({"font.family":"serif","font.size":9})
HERE=os.path.dirname(os.path.abspath(__file__))
D=os.path.join(HERE,"..","data"); FIG=os.path.join(HERE,"..","figures"); os.makedirs(FIG,exist_ok=True)
lc=lambda s:s.str.lower(); z=lambda x:(x-x.mean())/x.std()

def logit(X,y,cluster=None):
    b=np.zeros(X.shape[1])
    for _ in range(800):
        p=1/(1+np.exp(-(X@b))); W=p*(1-p)
        H=-(X*W[:,None]).T@X-1e-6*np.eye(X.shape[1]); g=X.T@(y-p)-1e-6*b
        step=np.linalg.solve(H,g); b-=step
        if np.max(np.abs(step))<1e-9: break
    A=np.linalg.inv(-H)
    if cluster is None:
        se=np.sqrt(np.diag(A))
    else:
        p=1/(1+np.exp(-(X@b))); u=(y-p)[:,None]*X; M=np.zeros((X.shape[1],)*2)
        for gid in np.unique(cluster):
            s=u[cluster==gid].sum(0)[:,None]; M+=s@s.T
        se=np.sqrt(np.diag(A@M@A))
    return np.exp(b), b/se

MK={"Aave V2":("aave_usdc_panel.csv","aave_v2"),"Compound V2":("compound_v2_usdc_panel.csv","compound_v2"),
    "Aave V3":("aave_v3_usdc_panel.csv","aave_v3"),"Compound V3":("compound_usdc_panel.csv","compound_v3")}
ten=pd.read_csv(f"{D}/tenure4.csv"); ten["owner"]=lc(ten.owner)
nf =pd.read_csv(f"{D}/net_usdc.csv"); nf["owner"]=lc(nf.owner)
mag=pd.read_csv(f"{D}/run_magnitude.csv"); mag["owner"]=lc(mag.owner)
frames=[]
for k,(f,proto) in MK.items():
    p=pd.read_csv(f"{D}/{f}"); p["owner"]=lc(p.owner)
    p=p.merge(ten[ten.proto==proto][["owner","tenure_days"]],on="owner",how="left")
    p=p.merge(nf[nf.market==proto][["owner","net_usdc"]],on="owner",how="left")
    p=p.merge(mag[mag.market==proto][["owner","ev_out","ev_in","pl_out"]],on="owner",how="left")
    for c in ["net_usdc","ev_out","ev_in","pl_out"]: p[c]=p[c].fillna(0.0)
    p["corr_bal0"]=p.bal0+p.net_usdc; p["mkt"]=k
    frames.append(p[(p.tx_sent_count>0)&(p.bal0>=100)])
R=pd.concat(frames,ignore_index=True); R=R[R.corr_bal0>=100].copy()      # reconstructed main sample

def flows(f):
    d=pd.read_csv(f"{D}/{f}"); d["day"]=pd.to_datetime(d.day); d=d.sort_values("day")
    base=d[(d.day>="2023-01-08")&(d.day<="2023-03-08")]; ev=d[(d.day>="2023-03-09")&(d.day<="2023-03-20")]
    mu,sd=base.outflow_usdc.mean(),base.outflow_usdc.std(ddof=0); peak=ev.outflow_usdc.max()
    d["cum"]=d.net_usdc.cumsum(); Rv=d[d.day<"2023-03-09"]["cum"].iloc[-1]
    return dict(abn_sd=(peak-mu)/sd, abn_res=(peak-mu)/Rv*100, cv=sd/mu,
                net5=-ev.head(5).net_usdc.sum()/Rv*100, net11=-ev.head(11).net_usdc.sum()/Rv*100, R=Rv/1e6)
A,C=flows("aave_usdc_daily_flows.csv"),flows("compound_usdc_daily_flows.csv")
print("TABLE 1  (Aave V2 | Compound V3):")
print(f"  abnormal peak / baseline s.d. : {A['abn_sd']:.1f} | {C['abn_sd']:.1f}  (ratio {A['abn_sd']/C['abn_sd']:.2f})")
print(f"  abnormal peak / reserve (%)   : {A['abn_res']:.1f} | {C['abn_res']:.1f}  (ratio {A['abn_res']/C['abn_res']:.2f})")
print(f"  baseline CV                   : {A['cv']:.2f} | {C['cv']:.2f}")
print(f"  5d / 11d net-depletion (%)    : {A['net5']:.1f}/{A['net11']:.1f} | {C['net5']:.1f}/{C['net11']:.1f}")
print(f"  reserve ($M)                  : {A['R']:.0f} | {C['R']:.0f}")

print("\nTABLE 2 Panel A (reconstructed):")
for k in MK:
    s=R[R.mkt==k]; b=np.sort(s.corr_bal0.values); rn=s.ran.to_numpy()[np.argsort(s.corr_bal0.values,kind="mergesort")]
    dec=[rn[ix].mean() for ix in np.array_split(np.arange(len(rn)),10)]
    print(f"  {k:12s} N={len(s):5d} run={s.ran.mean()*100:5.1f}% rhoS={spearmanr(range(10),dec).statistic:+.2f} top10$={b[int(len(b)*.9):].sum()/b.sum()*100:.0f}%")
Rt=R[R.tenure_days.notna()].copy()
Rt["zb"]=z(np.log10(Rt.corr_bal0.clip(lower=1))); Rt["zt"]=z(np.log10(Rt.tx_sent_count+1))
Rt["zg"]=z(np.log10(Rt.wallet_age_days+1));       Rt["zn"]=z(np.log10(Rt.tenure_days+1))
fe=pd.get_dummies(Rt.mkt,drop_first=True).values.astype(float); y=Rt.ran.values.astype(float)
X=np.column_stack([np.ones(len(Rt)),Rt.zb,Rt.zt,Rt.zg,Rt.zn]+[fe[:,i] for i in range(fe.shape[1])])
OR,zz=logit(X,y); _,zzc=logit(X,y,cluster=pd.factorize(Rt.owner)[0])
print(f"Panel B (market FE): size OR={OR[1]:.2f} (z={zz[1]:.1f}; clustered {zzc[1]:.1f})  tenure OR={OR[4]:.2f} (z={zz[4]:.1f}; clustered {zzc[4]:.1f})  N={len(Rt)}")
print("Panel C (per market):")
for k in MK:
    s=Rt[Rt.mkt==k]; Xs=np.column_stack([np.ones(len(s)),z(np.log10(s.corr_bal0.clip(lower=1))),z(np.log10(s.tx_sent_count+1)),z(np.log10(s.wallet_age_days+1)),z(np.log10(s.tenure_days+1))])
    o,zc=logit(Xs,s.ran.values.astype(float)); print(f"  {k:12s} N={len(s):5d} ev={int(s.ran.sum()):4d} size {o[1]:.2f}({zc[1]:+.1f}) tenure {o[4]:.2f}({zc[4]:+.1f})")

print("\nTABLE 3  withdrawal rate by tenure band (<=40 / 41-180 / >180 days):")
for k in MK:
    s=Rt[Rt.mkt==k]; cells=[s[s.tenure_days<=40],s[(s.tenure_days>40)&(s.tenure_days<=180)],s[s.tenure_days>180]]
    print(f"  {k:12s} "+"  ".join(f"{c.ran.mean()*100:.1f}%(n{len(c)})" if len(c)>=10 else "—" for c in cells))

# figures
def ci(p,n): return 1.96*math.sqrt(max(p*(1-p),1e-9)/max(n,1))*100
NB,NR="#1f4e79","#c0392b"
fig,ax=plt.subplots(1,3,figsize=(8.4,3.0))
for a_,v1,v2,ttl,yl,fmt in [(ax[0],A['abn_sd'],C['abn_sd'],"(a) Abnormal peak / s.d.","(sigma)","%.1f"),
    (ax[1],A['abn_res'],C['abn_res'],"(b) Same peak / reserve","% of reserve","%.1f%%"),
    (ax[2],A['net5'],C['net5'],"(c) 5-day net depletion / reserve","% of reserve","%.1f%%")]:
    a_.bar([0,1],[v1,v2],color=[NB,NR],width=.6); a_.set_xticks([0,1]); a_.set_xticklabels(["Aave V2","Compound V3"],fontsize=8)
    a_.set_title(ttl,fontsize=8.3); a_.set_ylabel(yl,fontsize=8); a_.set_ylim(0,max(v1,v2)*1.18)
    a_.text(0,v1,fmt%v1,ha="center",va="bottom",fontsize=8); a_.text(1,v2,fmt%v2,ha="center",va="bottom",fontsize=8)
fig.tight_layout(); fig.savefig(f"{FIG}/Figure_1_intensity.pdf",bbox_inches="tight"); plt.close(fig)
COL={"Aave V2":(NB,"o","-"),"Compound V2":("#2e86c1","s","-"),"Aave V3":(NR,"^","--"),"Compound V3":("#e67e22","D",":")}
fig,ax=plt.subplots(figsize=(6.4,3.9)); bins=[0,30,90,180,365,730,3000]; cen=[15,55,130,270,540,1200]
for k,(c,m,ls) in COL.items():
    s=R[(R.mkt==k)&R.tenure_days.notna()]; xs,ys,es=[],[],[]
    for i in range(len(bins)-1):
        sel=(s.tenure_days>=bins[i])&(s.tenure_days<bins[i+1]); n=int(sel.sum())
        if n>=15: pr=s.ran[sel].mean(); xs+=[cen[i]]; ys+=[pr*100]; es+=[ci(pr,n)]
    ax.errorbar(xs,ys,yerr=es,marker=m,ls=ls,color=c,lw=1.5,ms=6,capsize=2,label=k)
ax.set_xscale("log"); ax.set_xlabel("Deposit tenure at shock (days, log scale)"); ax.set_ylabel("Withdrawal rate (%)")
ax.legend(frameon=False,fontsize=8); ax.grid(alpha=.25); ax.set_xticks([15,30,90,365,730]); ax.set_xticklabels(["15","30","90","365","730"])
fig.savefig(f"{FIG}/Figure_2_tenure.pdf",bbox_inches="tight"); plt.close(fig)
fig,ax=plt.subplots(figsize=(6.4,3.8)); xr=np.arange(1,11)
for k,(c,m,ls) in COL.items():
    s=R[R.mkt==k]; parts=np.array_split(np.arange(len(s)),10); rn=s.ran.to_numpy()[np.argsort(s.corr_bal0.values,kind="mergesort")]
    dec=[rn[ix].mean()*100 for ix in parts]; es=[ci(d/100,len(ix)) for d,ix in zip(dec,parts)]
    ax.errorbar(xr,dec,yerr=es,marker=m,ls=ls,color=c,lw=1.4,ms=5,capsize=2,label=f"{k} (rho={spearmanr(xr,dec).statistic:.2f})")
ax.set_xlabel("Reconstructed pre-shock size decile"); ax.set_ylabel("Withdrawal rate (%)"); ax.legend(frameon=False,fontsize=7.5); ax.set_xticks(xr)
fig.savefig(f"{FIG}/Figure_3_size.pdf",bbox_inches="tight"); plt.close(fig)
print("\nFigures 1-3 written to ../figures/.  Done.")
