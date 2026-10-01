import pandas as pd
import streamlit as st

st.set_page_config(page_title="Nifty 50 Stock & Financial Analysis", layout="wide")

st.title("📊 Nifty 50 Stock & Financial Performance Analysis")
st.caption(
    "22 large-cap NSE companies across 10 sectors | ~5 years of price history "
    "| Data source: Yahoo Finance (yfinance), snapshot taken 28 Sep 2026"
)
st.warning(
    "This is a dataset analysis project for learning/portfolio purposes only. "
    "It is **not investment advice**.",
    icon="⚠️",
)

# ---- Load data (all built earlier in the pipeline) ----
try:
    summary = pd.read_csv("data/stock_summary.csv")
    prices = pd.read_csv("data/prices.csv", parse_dates=["Date"])
except FileNotFoundError as e:
    st.error(
        f"Could not find a data file: {e}. "
        "Run download_data.py, calculate_ratios.py and analysis_charts.py first."
    )
    st.stop()

summary["Ticker_short"] = summary["Ticker"].str.replace(".NS", "", regex=False)

# ---- Sidebar filter ----
st.sidebar.header("Filter")
sectors = sorted(summary["Sector"].unique())
chosen_sectors = st.sidebar.multiselect("Sector", sectors, default=sectors)
view = summary[summary["Sector"].isin(chosen_sectors)]

# ---- KPI row ----
col1, col2, col3, col4 = st.columns(4)
col1.metric("Companies shown", len(view))
col2.metric("Avg annual return", f"{view['annual_return_pct'].mean():.1f}%")
col3.metric("Avg volatility", f"{view['volatility_pct'].mean():.1f}%")
col4.metric("Avg ROE", f"{view['roe_pct'].mean():.1f}%")

st.divider()

# ---- Tabs ----
tab1, tab2, tab3, tab4 = st.tabs(
    ["Sector Comparison", "Risk vs Return", "Does ROE Predict Returns?", "Stock Explorer"]
)

with tab1:
    st.subheader("Average return, risk and ROE by sector")
    sector_table = (
        view.groupby("Sector")
        .agg(
            companies=("Ticker", "count"),
            avg_return_pct=("annual_return_pct", "mean"),
            avg_volatility_pct=("volatility_pct", "mean"),
            avg_roe_pct=("roe_pct", "mean"),
            avg_pe=("PE_Ratio", "mean"),
        )
        .round(1)
        .sort_values("avg_return_pct", ascending=False)
    )
    st.dataframe(sector_table, use_container_width=True)
    st.bar_chart(sector_table["avg_return_pct"])
    st.caption(
        "Sectors with only 1 company (Power, Infrastructure, Metals, Financial Services) "
        "are single-company results, not sector-level conclusions."
    )

with tab2:
    st.subheader("Risk vs Return — which stocks gave the best risk-adjusted returns?")
    st.image("charts/risk_vs_return.png", use_container_width=True)
    st.dataframe(
        view[["Ticker_short", "Sector", "annual_return_pct", "volatility_pct", "return_per_risk"]]
        .rename(columns={"Ticker_short": "Ticker"})
        .sort_values("return_per_risk", ascending=False)
        .round(2),
        use_container_width=True,
        hide_index=True,
    )

with tab3:
    st.subheader("Did higher ROE mean higher returns?")
    corr = view["roe_pct"].corr(view["annual_return_pct"])
    st.metric("Correlation (ROE vs annual return)", f"{corr:.2f}")
    st.image("charts/roe_vs_return.png", use_container_width=True)
    st.markdown(
        "**Finding:** the correlation is negative — companies with the highest ROE "
        "(FMCG, IT) did *not* have the highest returns in this 5-year window. "
        "Nestle (ROE ~80%) is an outlier pulling up the FMCG average."
    )

with tab4:
    st.subheader("Explore one stock's price history")
    choice = st.selectbox("Choose a company", sorted(view["Ticker_short"]))
    ticker_full = choice + ".NS"
    stock_prices = prices[prices["Ticker"] == ticker_full].set_index("Date")["Close"]
    st.line_chart(stock_prices)

    row = view[view["Ticker"] == ticker_full].iloc[0]
    c1, c2, c3, c4 = st.columns(4)
    c1.metric("Sector", row["Sector"])
    c2.metric("Annual return", f"{row['annual_return_pct']:.1f}%")
    c3.metric("Volatility", f"{row['volatility_pct']:.1f}%")
    c4.metric("ROE", f"{row['roe_pct']:.1f}%")

st.divider()
st.caption(
    "Built by Chinnadabbadi Meghana | Python, SQL (MySQL), Pandas, Streamlit | "
    "github.com/chinnadabbadimeghana-max"
)
