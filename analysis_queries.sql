-- =====================================================================
-- Nifty 50 Stock & Financial Performance Analysis  |  MySQL 8.0
-- Database: nifty50   Tables: prices (daily OHLCV), fundamentals (ratios)
-- Data source: yfinance snapshot (22 large-cap NSE companies, ~5 years)
-- Skills: GROUP BY, JOIN, CTE, window functions (RANK, LAG, FIRST_VALUE,
--         moving average)
-- Note: prices.Date is stored as text (MM/DD/YYYY), so STR_TO_DATE is
--       used wherever dates are sorted or grouped.
-- =====================================================================

USE nifty50;

-- =====================================================================
-- SECTION 1: DATA EXPLORATION
-- =====================================================================

-- 1.1 Row counts
SELECT COUNT(*) AS price_rows FROM prices;
SELECT COUNT(*) AS fundamentals_rows FROM fundamentals;

-- 1.2 Date range and number of stocks covered
SELECT MIN(STR_TO_DATE(`Date`, '%m/%d/%Y')) AS start_date,
       MAX(STR_TO_DATE(`Date`, '%m/%d/%Y')) AS end_date,
       COUNT(DISTINCT Ticker) AS total_stocks
FROM prices;


-- =====================================================================
-- SECTION 2: FUNDAMENTAL ANALYSIS
-- =====================================================================

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
-- Q3. Top 10 companies by market cap.
-- ---------------------------------------------------------------------
SELECT Company, Sector, MarketCap
FROM fundamentals
ORDER BY MarketCap DESC
LIMIT 10;


-- ---------------------------------------------------------------------
-- Q4. Quality screen: PE below 20 and ROE above 15%.
-- ---------------------------------------------------------------------
SELECT Company, Sector, PE_Ratio,
       ROUND(ROE_calc * 100, 1) AS roe_pct
FROM fundamentals
WHERE PE_Ratio < 20 AND ROE_calc > 0.15
ORDER BY ROE_calc DESC;


-- ---------------------------------------------------------------------
-- Q5. Top 5 dividend yields.
-- ---------------------------------------------------------------------
SELECT Company, DividendYield
FROM fundamentals
ORDER BY DividendYield DESC
LIMIT 5;


-- =====================================================================
-- SECTION 3: PRICE ANALYSIS
-- =====================================================================

-- ---------------------------------------------------------------------
-- Q6. Total return per stock over the full period (CTE + FIRST_VALUE).
-- ---------------------------------------------------------------------
WITH d AS (
  SELECT Ticker, STR_TO_DATE(`Date`, '%m/%d/%Y') AS dt, `Close` AS close_price
  FROM prices
),
r AS (
  SELECT Ticker,
         FIRST_VALUE(close_price) OVER (PARTITION BY Ticker ORDER BY dt)      AS first_close,
         FIRST_VALUE(close_price) OVER (PARTITION BY Ticker ORDER BY dt DESC) AS last_close
  FROM d
)
SELECT Ticker,
       ROUND(MAX(first_close), 2) AS first_close,
       ROUND(MAX(last_close), 2)  AS last_close,
       ROUND((MAX(last_close) / MAX(first_close) - 1) * 100, 2) AS total_return_pct
FROM r
GROUP BY Ticker
ORDER BY total_return_pct DESC;


-- ---------------------------------------------------------------------
-- Q7. Monthly average closing price trend (HDFC Bank).
-- ---------------------------------------------------------------------
SELECT DATE_FORMAT(STR_TO_DATE(`Date`, '%m/%d/%Y'), '%Y-%m') AS month,
       ROUND(AVG(`Close`), 2) AS avg_close
FROM prices
WHERE Ticker = 'HDFCBANK.NS'
GROUP BY month
ORDER BY month;


-- ---------------------------------------------------------------------
-- Q8. Top 10 highest-volume trading days.
-- ---------------------------------------------------------------------
SELECT Ticker, `Date`, Volume
FROM prices
ORDER BY Volume DESC
LIMIT 10;


-- ---------------------------------------------------------------------
-- Q9. 30-day moving average of closing price (TCS).
-- ---------------------------------------------------------------------
SELECT STR_TO_DATE(`Date`, '%m/%d/%Y') AS dt,
       `Close`,
       ROUND(AVG(`Close`) OVER (
         ORDER BY STR_TO_DATE(`Date`, '%m/%d/%Y')
         ROWS BETWEEN 29 PRECEDING AND CURRENT ROW), 2) AS ma_30
FROM prices
WHERE Ticker = 'TCS.NS'
ORDER BY dt;


-- =====================================================================
-- SECTION 4: RISK, RETURN AND FUNDAMENTALS COMBINED
-- =====================================================================

-- ---------------------------------------------------------------------
-- Q10. Annual return, volatility and return-per-risk for every stock.
-- daily return uses LAG(); 252 = trading days per year.
-- Simplified: annual return = average daily return x 252 (not CAGR);
-- return_per_risk is a Sharpe-like ratio without a risk-free rate.
-- ---------------------------------------------------------------------
WITH daily AS (
  SELECT Ticker, Sector,
         `Close` / LAG(`Close`) OVER (
             PARTITION BY Ticker
             ORDER BY STR_TO_DATE(`Date`, '%m/%d/%Y')) - 1 AS daily_return
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
-- Q11. Sector view: return and risk joined with fundamentals.
-- Caution: Power, Infrastructure, Metals and Financial Services have
-- only one company each, so they are not sector-level conclusions.
-- ---------------------------------------------------------------------
WITH daily AS (
  SELECT Ticker,
         `Close` / LAG(`Close`) OVER (
             PARTITION BY Ticker
             ORDER BY STR_TO_DATE(`Date`, '%m/%d/%Y')) - 1 AS daily_return
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


-- ---------------------------------------------------------------------
-- Q12. Best performing stock in each sector (CTEs + RANK).
-- ---------------------------------------------------------------------
WITH d AS (
  SELECT Ticker, Sector, STR_TO_DATE(`Date`, '%m/%d/%Y') AS dt, `Close` AS c
  FROM prices
),
r AS (
  SELECT Ticker, Sector,
         FIRST_VALUE(c) OVER (PARTITION BY Ticker ORDER BY dt)      AS f,
         FIRST_VALUE(c) OVER (PARTITION BY Ticker ORDER BY dt DESC) AS l
  FROM d
),
ret AS (
  SELECT Ticker, Sector, (MAX(l) / MAX(f) - 1) * 100 AS return_pct
  FROM r
  GROUP BY Ticker, Sector
)
SELECT Sector, Ticker, ROUND(return_pct, 2) AS return_pct,
       RANK() OVER (PARTITION BY Sector ORDER BY return_pct DESC) AS rnk
FROM ret
ORDER BY Sector, rnk;
