# 📊 Nifty 50 Stock & Financial Performance Analysis

A SQL + Python analysis of 22 large-cap NSE (Nifty 50) companies across 10 sectors, looking at
**risk, return, and fundamentals** — with an interactive Streamlit dashboard.

> ⚠️ This is a dataset analysis project for learning/portfolio purposes only. It is **not
> investment advice**.

---

## 🎯 Business Questions

1. Which sectors gave the best risk-adjusted returns?
2. Did companies with higher ROE actually deliver higher stock returns?
3. How risky (volatile) were different sectors compared to their returns?
4. Which individual stocks ranked best within their own sector on ROE?

---

## 🔍 Key Findings

- **Higher ROE did *not* mean higher returns.** Correlation between ROE and 5-year annual
  return across the 22 stocks was **-0.23** (-0.39 excluding an outlier). FMCG and IT had the
  highest average ROE but the *lowest* average returns of any sector.
- **Nestle India is an outlier** (ROE ~80%) that inflates the FMCG sector average — a good
  reminder to check individual companies before trusting a sector average.
- **Auto** had the best risk-adjusted return among sectors with 2+ companies (Bajaj Auto and
  Maruti both performed well relative to their volatility).
- The three lowest-PE stocks (ONGC, NTPC, SBIN) all delivered strong 5-year returns — but this
  is a snapshot pattern, not a predictive claim (PE is based on the end-of-period price).
- **Power, Infrastructure, Metals, and Financial Services each have only 1 company** in this
  dataset, so their "sector averages" are really single-company results, not sector conclusions.

Full SQL queries and comments: [`analysis_queries.sql`](analysis_queries.sql)

---

## 🛠️ How It Was Built

| Step | Tool | What it does |
|---|---|---|
| 1. Data collection | `yfinance` (Python) | Downloads 5 years of daily prices + financial ratios for 22 companies |
| 2. Ratio calculation | Pandas | Calculates ROE and Debt-to-Equity from raw financial statements for companies yfinance didn't provide them for |
| 3. Storage | MySQL 8.0 | Loads price and fundamentals data into two tables |
| 4. Analysis | SQL (MySQL) | `JOIN`, `GROUP BY`, `WITH` (CTEs), and window functions (`RANK()`, `LAG()`) to answer the business questions |
| 5. Validation | Python (Pandas) | Recomputes the same return/volatility stats independently to cross-check the SQL results |
| 6. Visualization | Matplotlib | Risk-vs-return and ROE-vs-return scatter charts |
| 7. Dashboard | Streamlit | Interactive dashboard with sector filters, charts, and a per-stock price explorer |

---

## 📂 Project Structure

```
nifty50-stock-analysis/
├── download_data.py          # Step 1: download prices + fundamentals via yfinance
├── calculate_ratios.py       # Step 2: calculate ROE & Debt-to-Equity from financial statements
├── load_data.py              # Step 3: load CSVs into MySQL
├── analysis_queries.sql      # Step 4: the 4 core SQL analysis queries, with comments
├── analysis_charts.py        # Step 5-6: reads MySQL, validates stats, saves charts
├── app.py                    # Step 7: Streamlit dashboard
├── charts/                   # Generated PNG charts
├── data/                     # Generated CSVs (prices, fundamentals, summary)
└── requirements.txt
```

---

## ⚙️ How to Run

```bash
# 1. Install dependencies
pip install yfinance pandas sqlalchemy pymysql cryptography python-dotenv matplotlib streamlit

# 2. Download data
python download_data.py
python calculate_ratios.py

# 3. Set up MySQL
#    - Create a database named `nifty50` in MySQL Workbench / CLI
#    - Create a `.env` file inside data/ with: MYSQL_PASSWORD=your_password

# 4. Load data into MySQL
python load_data.py

# 5. Run the SQL queries in analysis_queries.sql (MySQL Workbench or CLI)

# 6. Generate charts + summary CSV
python analysis_charts.py

# 7. Launch the dashboard
streamlit run app.py
```

---

## ⚠️ Data Notes & Caveats

- Data snapshot taken **28 September 2026** via Yahoo Finance (`yfinance`). Prices and ratios
  will differ if re-run on a later date.
- `annual_return_pct` is a simplified annualisation (average daily return × 252), not CAGR.
- `return_per_risk` is a simplified Sharpe-like ratio and does **not** subtract a risk-free rate.
- ROE and Debt-to-Equity were calculated from the latest available annual statements, which can
  differ from yfinance's trailing-twelve-month figures (e.g. HDFC Bank: 8.6% calculated vs 13.8%
  from yfinance).
- Debt-to-Equity is not meaningful for banks (their "debt" is customer deposits), so bank D/E
  values were excluded from that comparison.
- This is a 5-year historical window for 22 companies — not a statistically robust sample for
  drawing general conclusions about sectors or predicting future performance.

---

## 👩‍💻 About Me

Built by **Chinnadabbadi Meghana** — MCA graduate with a finance/auditing background, combining
SQL, Python, and financial domain knowledge. This project is part of a portfolio focused on
"finance + AI/data" work.

- LinkedIn: [linkedin.com/in/chinnadabbadi-meghana](https://www.linkedin.com/in/chinnadabbadi-meghana-00981b401)
- GitHub: [github.com/chinnadabbadimeghana-max](https://github.com/chinnadabbadimeghana-max)

See [`LICENSE`](LICENSE) for usage terms.
