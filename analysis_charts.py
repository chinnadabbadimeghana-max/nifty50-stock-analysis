import os
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")  # save charts as files, no pop-up window
import matplotlib.pyplot as plt
from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL

load_dotenv()
load_dotenv("data/.env")

password = os.getenv("MYSQL_PASSWORD")
if not password:
    raise SystemExit("MYSQL_PASSWORD not found. Check your .env file and save it (Ctrl+S).")

engine = create_engine(
    URL.create(
        "mysql+pymysql",
        username="root",
        password=password,
        host="localhost",
        port=3306,
        database="nifty50",
    )
)

# ---- 1. Read data from MySQL ----
prices = pd.read_sql(
    text("SELECT Ticker, `Date`, `Close` FROM prices ORDER BY Ticker, `Date`"), engine
)
fund = pd.read_sql(
    text("SELECT Ticker, Company, Sector, ROE_calc, PE_Ratio FROM fundamentals"), engine
)

# ---- 2. Daily returns, annual return, volatility (same formulas as the SQL) ----
prices["daily_return"] = prices.groupby("Ticker")["Close"].pct_change()
stats = (
    prices.dropna(subset=["daily_return"])
    .groupby("Ticker")["daily_return"]
    .agg(mean="mean", std=lambda x: x.std(ddof=0))  # ddof=0 matches MySQL STDDEV
)
stats["annual_return_pct"] = stats["mean"] * 252 * 100
stats["volatility_pct"] = stats["std"] * np.sqrt(252) * 100
stats["return_per_risk"] = stats["annual_return_pct"] / stats["volatility_pct"]

summary = fund.merge(
    stats[["annual_return_pct", "volatility_pct", "return_per_risk"]].reset_index(),
    on="Ticker",
)
summary["roe_pct"] = summary["ROE_calc"] * 100
summary.to_csv("data/stock_summary.csv", index=False)

print("Top 5 by annual return (compare with your SQL result):")
print(
    summary[["Ticker", "annual_return_pct", "volatility_pct"]]
    .sort_values("annual_return_pct", ascending=False)
    .head(5)
    .round(1)
    .to_string(index=False)
)

# ---- 3. Chart 1: risk vs return ----
os.makedirs("charts", exist_ok=True)
sectors = sorted(summary["Sector"].unique())
colors = plt.cm.tab10(np.linspace(0, 1, len(sectors)))
color_map = dict(zip(sectors, colors))

fig, ax = plt.subplots(figsize=(11, 7))
for sector in sectors:
    d = summary[summary["Sector"] == sector]
    ax.scatter(
        d["volatility_pct"], d["annual_return_pct"],
        s=90, color=color_map[sector], label=sector,
    )
for _, r in summary.iterrows():
    ax.annotate(
        r["Ticker"].replace(".NS", ""),
        (r["volatility_pct"], r["annual_return_pct"]),
        textcoords="offset points", xytext=(6, 4), fontsize=8,
    )
ax.axhline(0, color="grey", linewidth=0.8)
ax.set_xlabel("Volatility (annualised, %)")
ax.set_ylabel("Average annual return (%)")
ax.set_title("Risk vs Return: 22 Nifty 50 stocks (about 5 years)")
ax.legend(title="Sector", fontsize=8)
ax.grid(alpha=0.3)
fig.savefig("charts/risk_vs_return.png", dpi=150, bbox_inches="tight")
plt.close(fig)

# ---- 4. Chart 2: does ROE predict return? ----
corr_all = summary["roe_pct"].corr(summary["annual_return_pct"])
no_nestle = summary[summary["Ticker"] != "NESTLEIND.NS"]
corr_ex = no_nestle["roe_pct"].corr(no_nestle["annual_return_pct"])
print(f"\nCorrelation ROE vs return (all 22 stocks): {corr_all:.2f}")
print(f"Correlation ROE vs return (without Nestle): {corr_ex:.2f}")

fig, ax = plt.subplots(figsize=(10, 6.5))
ax.scatter(summary["roe_pct"], summary["annual_return_pct"], s=80, color="#1f77b4")
for _, r in summary.iterrows():
    ax.annotate(
        r["Ticker"].replace(".NS", ""),
        (r["roe_pct"], r["annual_return_pct"]),
        textcoords="offset points", xytext=(6, 4), fontsize=8,
    )
slope, intercept = np.polyfit(summary["roe_pct"], summary["annual_return_pct"], 1)
xs = np.linspace(summary["roe_pct"].min(), summary["roe_pct"].max(), 50)
ax.plot(xs, slope * xs + intercept, "--", color="red",
        label=f"trend line (correlation = {corr_all:.2f})")
ax.axhline(0, color="grey", linewidth=0.8)
ax.set_xlabel("ROE (%)")
ax.set_ylabel("Average annual return (%)")
ax.set_title("Did higher ROE mean higher returns?")
ax.legend()
ax.grid(alpha=0.3)
fig.savefig("charts/roe_vs_return.png", dpi=150, bbox_inches="tight")
plt.close(fig)

print("\nDone! Charts saved in the charts folder, summary in data/stock_summary.csv")
