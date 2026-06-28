"""
Regenerate Figures 1-6 of the paper from the CSV extracts in ../data/.
Outputs vector PDF + 300 dpi PNG into ./figures/.  Run: python reproduce_figures.py
"""
import os, numpy as np, pandas as pd
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
plt.rcParams.update({"font.family":"serif","font.size":10})
D="../data/"; OUT="figures"; os.makedirs(OUT, exist_ok=True)
def save(fig,name):
    fig.savefig(f"{OUT}/{name}.pdf",bbox_inches="tight")
    fig.savefig(f"{OUT}/{name}.png",dpi=300,bbox_inches="tight"); plt.close(fig)
def deciles(csv):
    df=pd.read_csv(D+csv); bal=df.bal0.to_numpy(float); tx=df.tx_sent_count.to_numpy(float); ran=df.ran.to_numpy(float)
    m=(tx>0)&(bal>=100); b,rn=bal[m],ran[m]; o=np.argsort(b,kind="mergesort"); b,rn=b[o],rn[o]
    return [rn[ix].mean()*100 for ix in np.array_split(np.arange(len(b)),10)]

# Figure 1 — event study
fig,ax=plt.subplots(figsize=(6.2,3.4))
for csv,lab,c in [("aave_usdc_daily_flows.csv","Aave V2","#1f4e79"),("compound_usdc_daily_flows.csv","Compound V3","#c0392b")]:
    d=pd.read_csv(D+csv); d["day"]=pd.to_datetime(d["day"])
    base=d[(d.day>="2023-01-08")&(d.day<="2023-03-08")]["outflow_usdc"]; mu,sd=base.mean(),base.std(ddof=0)
    w=d[(d.day>="2023-02-20")&(d.day<="2023-03-25")].sort_values("day")
    ax.plot(range(len(w)),(w["outflow_usdc"]-mu)/sd,marker="o",ms=3,lw=1.2,label=lab,color=c)
    days=list(w["day"].dt.strftime("%m-%d"))
ax.set_xticks(range(0,len(days),5)); ax.set_xticklabels([days[i] for i in range(0,len(days),5)],rotation=45,fontsize=7)
ax.set_ylabel(r"Abnormal daily outflow $AF_t$ ($\sigma$)"); ax.set_xlabel("2023")
ax.set_title("Aggregate run: standardized outflow spike",fontsize=10); ax.legend(frameon=False,fontsize=8)
save(fig,"Figure_1")

# data for Figs 2,3
df=pd.read_csv(D+"aave_usdc_panel.csv")
bal=df.bal0.to_numpy(float); tx=df.tx_sent_count.to_numpy(float); ran=df.ran.to_numpy(float)
fwh=pd.to_numeric(df.first_wd_hours,errors="coerce").to_numpy(float)
m=(tx>0)&(bal>=100); b,rn,fw=bal[m],ran[m],fwh[m]; o=np.argsort(b,kind="mergesort"); b,rn,fw=b[o],rn[o],fw[o]
idx=np.array_split(np.arange(len(b)),10)
wr=[rn[ix].mean()*100 for ix in idx]; mt=[np.median(fw[ix][rn[ix]==1]) if (rn[ix]==1).any() else np.nan for ix in idx]

# Figure 2 — who runs deciles
fig,ax1=plt.subplots(figsize=(6.2,3.4)); x=np.arange(1,11)
ax1.bar(x,wr,color="#1f4e79",alpha=.85); ax1.set_xlabel("Pre-shock size decile (D10 = largest)")
ax1.set_ylabel("Withdrawal rate (%)",color="#1f4e79"); ax1.set_xticks(x)
ax2=ax1.twinx(); ax2.plot(x,mt,color="#c0392b",marker="s",ms=4,lw=1.4); ax2.set_ylabel("Median run time (h)",color="#c0392b"); ax2.grid(False)
ax1.set_title(r"Who runs: size gradient ($\rho_S$=0.98), earlier running ($\rho_O$=$-$0.83)",fontsize=9.5)
save(fig,"Figure_2")

# Figure 3 — Kaplan-Meier by size tercile
T=np.where(rn==1,np.maximum(fw,0.5),144.0); grp=np.digitize(b,np.quantile(b,[1/3,2/3]))
def km(T,E):
    o=np.argsort(T); T,E=T[o],E[o]; S=1.0; xs=[0]; ys=[0.0]
    for t in np.unique(T):
        d=((T==t)&(E==1)).sum(); nr=(T>=t).sum()
        if d>0: S*=(1-d/nr); xs.append(t); ys.append(1-S)
    return np.array(xs),np.array(ys)
fig,ax=plt.subplots(figsize=(6.2,3.4))
for g,lab,c in zip([0,1,2],["Small (bottom third)","Medium","Large (top third)"],["#7fb3d5","#2e86c1","#1f4e79"]):
    xs,ys=km(T[grp==g],rn[grp==g]); ax.step(xs,ys*100,where="post",label=lab,color=c,lw=1.6)
ax.set_xlabel("Hours since depeg onset"); ax.set_ylabel("Cumulative run incidence (%)"); ax.set_xlim(0,144)
ax.set_title("Larger depositors run more — and earlier (Kaplan-Meier)",fontsize=10); ax.legend(frameon=False,fontsize=8,loc="upper left")
save(fig,"Figure_3")

# Figure 4 — herding
h=pd.read_csv(D+"aave_usdc_hourly_herding.csv"); h["hour"]=pd.to_datetime(h["hour"]); h=h.sort_values("hour")
w=h["n_wd_wallets"].to_numpy(); base=h[h.hour<"2023-03-09"]["n_wd_wallets"]
fig,ax=plt.subplots(figsize=(6.2,3.0)); ax.bar(range(len(w)),w,width=1.0,color="#1f4e79")
ax.axhline(base.max(),color="gray",ls="--",lw=.8); ax.text(2,base.max()+.6,f"normal max = {int(base.max())}",fontsize=7)
pk=int(np.argmax(w)); ax.annotate(f"peak {int(w.max())}",(pk,w.max()),(pk-70,w.max()-6),fontsize=7,arrowprops=dict(arrowstyle="->",lw=.7))
xt=list(range(0,len(h),48)); ax.set_xticks(xt); ax.set_xticklabels([h["hour"].dt.strftime("%m-%d").iloc[i] for i in xt],rotation=45,fontsize=7)
ax.set_ylabel("Distinct withdrawing\nwallets / hour"); ax.set_xlabel("2023"); ax.set_title("Herding: sustained concurrency, not a flash",fontsize=10)
save(fig,"Figure_4")

# Figure 5 — 4-panel replication
cells=[("Aave V2 . USDC . 2023 (SVB)","aave_usdc_panel.csv",0.982,"#1f4e79"),
       ("Compound V3 . USDC . 2023 (SVB)","compound_usdc_panel.csv",0.900,"#1f4e79"),
       ("Aave V2 . USDT . 2023 (SVB contagion)","aave_usdt_2023_panel.csv",0.874,"#c0392b"),
       ("Aave V2 . USDT . 2022 (Terra collapse)","aave_usdt_2022_panel.csv",0.985,"#c0392b")]
fig,axs=plt.subplots(2,2,figsize=(7.6,5.2)); axs=axs.ravel(); x=np.arange(1,11)
for ax,(title,csv,rs,c) in zip(axs,cells):
    ax.bar(x,deciles(csv),color=c); ax.set_title(f"{title}\n"+r"$\rho_S$ = %.3f"%rs,fontsize=8.5)
    ax.set_xticks(x); ax.set_xlabel("Size decile",fontsize=8); ax.set_ylabel("Withdrawal rate (%)",fontsize=8)
fig.suptitle("Replication of the size-run gradient across two protocols, two assets, and two shocks",fontsize=10,y=1.01)
fig.tight_layout(); save(fig,"Figure_5")

# Figure 6 — welfare
rs=pd.read_csv(D+"welfare_runner_sells.csv"); price=pd.read_csv(D+"usdc_minute_price.csv")
price["ts"]=pd.to_datetime(price["ts"]); pts=price["ts"].astype("int64").to_numpy(); pvl=price["price"].to_numpy()
panel=pd.read_csv(D+"aave_usdc_panel.csv"); panel=panel[(panel.ran==1)&(panel.tx_sent_count>0)&(panel.bal0>=100)]
A=rs.set_index(rs["owner"].str.lower())
ba=panel.bal0.to_numpy(float)
own=panel["owner"].str.lower()
du=np.array([int(A["dumped"].get(o,0)) if o in A.index else 0 for o in own])
o=np.argsort(ba,kind="mergesort"); dm=du[o]
DR=[dm[ix].mean()*100 for ix in np.array_split(np.arange(len(dm)),10)]
def disc_at(tstr):
    if pd.isna(tstr): return np.nan
    t=pd.to_datetime(tstr).value; i=min(np.searchsorted(pts,t),len(pvl)-1); return (1-pvl[i])*100
disc=[disc_at(t) for t,d in zip(rs.get("first_sell_time"),rs["dumped"]) if d==1 and pd.notna(t)]
disc=[x for x in disc if pd.notna(x)]
fig,(a1,a2)=plt.subplots(1,2,figsize=(7.6,3.3)); x=np.arange(1,11)
a1.bar(x,DR,color="#1f4e79"); a1.axhline(rs["dumped"].mean()*100,ls="--",c="#1f4e79",lw=1.2,label="All runners")
a1.set_xlabel("Pre-shock size decile"); a1.set_ylabel("USDC-dump rate (%)"); a1.set_xticks(x)
a1.set_title("Who realizes the loss?",fontsize=9.5); a1.legend(fontsize=7,frameon=False)
a2.hist(disc,bins=np.arange(0,12,0.75),color="#c0392b",alpha=0.85)
a2.set_xlabel("Realized discount at sale (% below par)"); a2.set_ylabel("Dumpers"); a2.set_title("How much do dumpers lose?",fontsize=9.5)
fig.suptitle("Post-withdrawal welfare: most runners avoid the loss; a small-depositor minority panics",fontsize=9.5,y=1.03)
fig.tight_layout(); save(fig,"Figure_6")
print("Wrote Figures 1-6 (PDF + PNG) to ./figures/")
