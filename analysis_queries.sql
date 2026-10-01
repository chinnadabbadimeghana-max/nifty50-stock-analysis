-- =====================================================================
-- Nifty 50 Stock & Financial Performance Analysis  |  MySQL 8.0
-- Database: nifty50   Tables: prices (daily OHLCV), fundamentals (ratios)
-- Data source: yfinance snapshot (22 large-cap NSE companies, ~5 years)
-- =====================================================================

USE nifty50;

-- ---------------------------------------------------------------------
-- Q1. Which sectors have the highest ROE, and how are they valued (PE)?
-- Note: Nestle (ROE ~80%) is an outlier that lifts the FMCG average.
-- ---------------------------------------------------------------------
SELECT Sector,
       COUNT(*) AS companies,
       ROUND(AVG(ROE_calc) * 100, 1) AS avg_roe_pct,
       ROUND(AVG(PE_Ratio), 1) AS avg_pe
FROM fundamentals
GROUP BY Sector
ORDER BY avg_roe_pct DESC;


-- ---------------------------------------------------------------------
-- Q2. Rank companies inside each sector by ROE (window function).
-- ROE_calc = Net Income / Stockholders Equity, from the latest annual
-- statements (may differ from yfinance's trailing-12-month ROE).
-- ---------------------------------------------------------------------
SELECT Ticker, Sector,
       ROUND(ROE_calc * 100, 1) AS roe_pct,
       ROUND(PE_Ratio, 1) AS pe,
       RANK() OVER (PARTITION BY Sector ORDER BY ROE_calc DESC) AS rank_in_sector
FROM fundamentals
ORDER BY Sector, rank_in_sector;


-- ---------------------------------------------------------------------
-- Q3. Annual return, volatility and return-per-risk for every stock.
-- daily return uses LAG(); 252 = trading days per year.
-- Simplified: annual return = average daily return x 252 (not CAGR);
-- return_per_risk is a Sharpe-like ratio without a risk-free rate.
-- ---------------------------------------------------------------------
WITH daily AS (
  SELECT Ticker, Sector, `Date`,
         `Close` / LAG(`Close`) OVER (PARTITION BY Ticker ORDER BY `Date`) - 1 AS daily_return
  FROM prices
)
SELECT Ticker, Sector,
       ROUND(AVG(daily_return) * 252 * 100, 1) AS annual_return_pct,
       ROUND(STDDEV(daily_return) * SQRT(252) * 100, 1) AS volatility_pct,
       ROUND(AVG(daily_return) * 252 / (STDDEV(daily_return) * SQRT(252)), 2) AS return_per_risk
FROM daily
WHERE daily_return IS NOT NULL
GROUP BY Ticker, Sector
ORDER BY return_per_risk DESC;


-- ---------------------------------------------------------------------
-- Q4. Sector view: return and risk joined with fundamentals.
-- Caution: Power, Infrastructure, Metals and Financial Services have
-- only one company each, so they are not sector-level conclusions.
-- ---------------------------------------------------------------------
WITH daily AS (
  SELECT Ticker, `Date`,
         `Close` / LAG(`Close`) OVER (PARTITION BY Ticker ORDER BY `Date`) - 1 AS daily_return
  FROM prices
),
stock_stats AS (
  SELECT Ticker,
         AVG(daily_return) * 252 * 100 AS annual_return_pct,
         STDDEV(daily_return) * SQRT(252) * 100 AS volatility_pct
  FROM daily
  WHERE daily_return IS NOT NULL
  GROUP BY Ticker
)
SELECT f.Sector,
       COUNT(*) AS companies,
       ROUND(AVG(s.annual_return_pct), 1) AS avg_return_pct,
       ROUND(AVG(s.volatility_pct), 1) AS avg_volatility_pct,
       ROUND(AVG(f.ROE_calc) * 100, 1) AS avg_roe_pct,
       ROUND(AVG(f.PE_Ratio), 1) AS avg_pe
FROM stock_stats s
JOIN fundamentals f ON f.Ticker = s.Ticker
GROUP BY f.Sector
ORDER BY avg_return_pct DESC;
