import pandas as pd
import yfinance as yf

fund = pd.read_csv("data/fundamentals.csv")


def pick(df, labels):
    """Return the latest value for the first label found in the statement."""
    for label in labels:
        if label in df.index:
            value = df.loc[label].dropna()
            if len(value) > 0:
                return float(value.iloc[0])
    return None


rows = []
for ticker in fund["Ticker"]:
    print(f"Calculating {ticker} ...")
    try:
        stock = yf.Ticker(ticker)
        income = stock.financials
        balance = stock.balance_sheet

        net_income = pick(income, ["Net Income", "Net Income Common Stockholders"])
        equity = pick(balance, ["Stockholders Equity", "Common Stock Equity",
                                "Total Equity Gross Minority Interest"])
        total_debt = pick(balance, ["Total Debt"])

        roe_calc = net_income / equity if net_income and equity else None
        de_calc = total_debt / equity if total_debt and equity else None

        rows.append({
            "Ticker": ticker,
            "NetIncome": net_income,
            "Equity": equity,
            "TotalDebt": total_debt,
            "ROE_calc": roe_calc,
            "DE_calc": de_calc,
        })
    except Exception as e:
        print(f"  Skipped {ticker}: {e}")

calc = pd.DataFrame(rows)
merged = fund.merge(calc, on="Ticker", how="left")
merged.to_csv("data/fundamentals_calculated.csv", index=False)

print("\nDone!")
print(merged[["Ticker", "ROE", "ROE_calc", "DebtToEquity", "DE_calc"]])
