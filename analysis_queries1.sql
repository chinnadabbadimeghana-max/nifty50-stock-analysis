-- =====================================================================
-- Nifty 50 Stock & Financial Performance Analysis (MySQL)
-- Tables : prices (daily OHLCV per ticker), fundamentals (ratios per company)
-- Skills : GROUP BY, JOIN, CTE, window functions (FIRST_VALUE, LAG, RANK, moving avg)
-- Note   : prices.Date is stored as text (MM/DD/YYYY), so STR_TO_DATE is used.
-- =====================================================================

USE nifty50;

-- =====================================================================
-- 1. DATA EXPLORATION
-- =====================================================================

-- Tables in the database
SHOW TABLES;

-- Table structure
DESCRIBE prices;
DESCRIBE fundamentals;

-- Row counts
SELECT COUNT(*) AS price_rows FROM prices;
SELECT COUNT(*) AS fundamentals_rows FROM fundamentals;

-- Date range and number of stocks covered
SELECT MIN(STR_TO_DATE(`Date`, '%m/%d/%Y')) AS start_date,
       MAX(STR_TO_DATE(`Date`, '%m/%d/%Y')) AS end_date,
       COUNT(DISTINCT Ticker) AS total_stocks
FROM prices;


-- =====================================================================
-- 2. FUNDAMENTAL ANALYSIS
-- =====================================================================

-- 2.1 Sector-wise average PE, ROE and profit margin
SELECT Sector,
       COUNT(*) AS companies,
       ROUND(AVG(PE_Ratio), 2) AS avg_pe,
       ROUND(AVG(ROE), 3) AS avg_roe,
       ROUND(AVG(ProfitMargin), 3) AS avg_margin
FROM fundamentals
GROUP BY Sector
ORDER BY avg_roe DESC;

-- 2.2 Top 10 companies by market cap
SELECT Company, Sector, MarketCap
FROM fundamentals
ORDER BY MarketCap DESC
LIMIT 10;

-- 2.3 Quality stocks: low PE (< 20) and high ROE (> 15%)
SELECT Company, Sector, PE_Ratio, ROE
FROM fundamentals
WHERE PE_Ratio < 20 AND ROE > 0.15
ORDER BY ROE DESC;

-- 2.4 Top 5 dividend yields
SELECT Company, DividendYield
FROM fundamentals
ORDER BY DividendYield DESC
LIMIT 5;


-- =====================================================================
-- 3. PRICE ANALYSIS
-- =====================================================================

-- 3.1 Total return per stock (CTE + FIRST_VALUE window function)
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

-- 3.2 Monthly average closing price (HDFC Bank)
SELECT DATE_FORMAT(STR_TO_DATE(`Date`, '%m/%d/%Y'), '%Y-%m') AS month,
       ROUND(AVG(`Close`), 2) AS avg_close
FROM prices
WHERE Ticker = 'HDFCBANK.NS'
GROUP BY month
ORDER BY month;

-- 3.3 Top 10 highest-volume trading days
SELECT Ticker, `Date`, Volume
FROM prices
ORDER BY Volume DESC
LIMIT 10;

-- 3.4 Volatility per stock (std deviation of daily returns, using LAG)
WITH daily AS (
  SELECT Ticker,
         STR_TO_DATE(`Date`, '%m/%d/%Y') AS dt,
         `Close` / LAG(`Close`) OVER (
             PARTITION BY Ticker
             ORDER BY STR_TO_DATE(`Date`, '%m/%d/%Y')) - 1 AS daily_return
  FROM prices
)
SELECT Ticker,
       ROUND(STDDEV(daily_return) * 100, 3) AS volatility_pct
FROM daily
WHERE daily_return IS NOT NULL
GROUP BY Ticker
ORDER BY volatility_pct DESC;

-- 3.5 30-day moving average of closing price (TCS)
SELECT STR_TO_DATE(`Date`, '%m/%d/%Y') AS dt,
       `Close`,
       ROUND(AVG(`Close`) OVER (
         ORDER BY STR_TO_DATE(`Date`, '%m/%d/%Y')
         ROWS BETWEEN 29 PRECEDING AND CURRENT ROW), 2) AS ma_30
FROM prices
WHERE Ticker = 'TCS.NS'
ORDER BY dt;


-- =====================================================================
-- 4. COMBINED ANALYSIS (prices + fundamentals)
-- =====================================================================

-- 4.1 Sector-wise volatility (avg daily high-low range) vs fundamentals (JOIN)
SELECT p.Sector,
       COUNT(DISTINCT p.Ticker) AS stocks,
       ROUND(AVG((p.High - p.Low) / p.`Close`) * 100, 2) AS avg_daily_range_pct,
       ROUND(AVG(f.PE_Ratio), 2) AS avg_pe,
       ROUND(AVG(f.ROE), 3) AS avg_roe
FROM prices p
JOIN fundamentals f ON p.Ticker = f.Ticker
GROUP BY p.Sector
ORDER BY avg_daily_range_pct DESC;

-- 4.2 Best performing stock in each sector (CTEs + RANK)
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
