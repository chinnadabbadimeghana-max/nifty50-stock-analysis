import os
import yfinance as yf
import pandas as pd

# 22 large Nifty 50 companies across 9 sectors (ticker: sector)
TICKERS = {
    "HDFCBANK.NS": "Banking",
    "ICICIBANK.NS": "Banking",
    "SBIN.NS": "Banking",
    "KOTAKBANK.NS": "Banking",
    "AXISBANK.NS": "Banking",
    "BAJFINANCE.NS": "Financial Services",
    "TCS.NS": "IT",
    "INFY.NS": "IT",
    "WIPRO.NS": "IT",
    "HCLTECH.NS": "IT",
    "RELIANCE.NS": "Energy",
    "ONGC.NS": "Energy",
    "NTPC.NS": "Power",
    "HINDUNILVR.NS": "FMCG",
    "ITC.NS": "FMCG",
    "NESTLEIND.NS": "FMCG",
    "MARUTI.NS": "Auto",
    "BAJAJ-AUTO.NS": "Auto",
    "SUNPHARMA.NS": "Pharma",
    "DRREDDY.NS": "Pharma",
    "TATASTEEL.NS": "Metals",
    "LT.NS": "Infrastructure",
}

os.makedirs("data", exist_ok=True)

price_frames = []
fundamentals = []

for ticker, sector in TICKERS.items():
    print(f"Downloading {ticker} ...")
    try:
        stock = yf.Ticker(ticker)

        # 5 years of daily prices
        hist = stock.history(period="5y").reset_index()
        hist["Date"] = hist["Date"].dt.tz_localize(None)
        hist["Ticker"] = ticker
        hist["Sector"] = sector
        price_frames.append(hist)

        # key financial ratios (some may be missing for some companies)
        info = stock.info
        fundamentals.append({
            "Ticker": ticker,
            "Company": info.get("longName"),
            "Sector": sector,
            "MarketCap": info.get("marketCap"),
            "PE_Ratio": info.get("trailingPE"),
            "ROE": info.get("returnOnEquity"),
            "DebtToEquity": info.get("debtToEquity"),
            "RevenueGrowth": info.get("revenueGrowth"),
            "ProfitMargin": info.get("profitMargins"),
            "DividendYield": info.get("dividendYield"),
        })
    except Exception as e:
        print(f"  Skipped {ticker}: {e}")

prices = pd.concat(price_frames, ignore_index=True)
prices.to_csv("data/prices.csv", index=False)

pd.DataFrame(fundamentals).to_csv("data/fundamentals.csv", index=False)

print(f"\nDone! prices.csv rows: {len(prices)}, companies: {len(fundamentals)}")
