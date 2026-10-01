import os
import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL
from sqlalchemy.types import String

# .env can be in the project folder or inside the data folder
load_dotenv()
load_dotenv("data/.env")

password = os.getenv("MYSQL_PASSWORD")
if not password:
    raise SystemExit("MYSQL_PASSWORD not found. Check your .env file and save it (Ctrl+S).")

# URL.create handles special characters like @ in the password safely
url = URL.create(
    "mysql+pymysql",
    username="root",
    password=password,
    host="localhost",
    port=3306,
    database="nifty50",
)
engine = create_engine(url)

prices = pd.read_csv("data/prices.csv", parse_dates=["Date"])
prices = prices.rename(columns={"Stock Splits": "Stock_Splits"})

fund = pd.read_csv("data/fundamentals_calculated.csv")

print("Loading prices table ...")
prices.to_sql(
    "prices", engine, if_exists="replace", index=False, chunksize=5000,
    dtype={"Ticker": String(20), "Sector": String(30)},
)

print("Loading fundamentals table ...")
fund.to_sql(
    "fundamentals", engine, if_exists="replace", index=False,
    dtype={"Ticker": String(20), "Company": String(100), "Sector": String(30)},
)

with engine.connect() as conn:
    n_prices = conn.execute(text("SELECT COUNT(*) FROM prices")).scalar()
    n_fund = conn.execute(text("SELECT COUNT(*) FROM fundamentals")).scalar()

print(f"\nDone! prices rows: {n_prices}, fundamentals rows: {n_fund}")
