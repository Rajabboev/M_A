"""W15: copy RetailUZ from SQL Server (Docker) into ClickHouse.

Run:
  .venv\\Scripts\\python scripts\\load_clickhouse.py                 # full reload of all tables
  .venv\\Scripts\\python scripts\\load_clickhouse.py --incremental   # sales: only SaleID > max in ClickHouse

Flow per table:  SQL Server --(pandas, chunks)--> DataFrame --(clickhouse-connect insert_df)--> ClickHouse
Then it compares row counts and SUM(Amount) on both sides.
"""
import argparse
import os
import sys
import time
from pathlib import Path
from urllib.parse import quote_plus

import clickhouse_connect
import pandas as pd
import sqlalchemy as sa
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[1]
load_dotenv(ROOT / ".env")

CHUNK = 50_000

# source query (SQL Server)  ->  target table (ClickHouse). Column names match 1:1.
TABLES = {
    "region":  "SELECT RegionID, RegionName FROM dbo.Region",
    "store":   "SELECT StoreID, StoreName, RegionID FROM dbo.Store",
    "product": "SELECT ProductID, ProductName, Category, UnitPrice FROM dbo.Product",
    "sales":   "SELECT SaleID, SaleDate, StoreID, ProductID, Qty, Amount FROM dbo.Sales",
}

# pandas dtypes that match the ClickHouse column types (pyodbc returns DATE as object/str)
DTYPES = {
    "sales": {"SaleID": "uint32", "StoreID": "uint16", "ProductID": "uint16", "Qty": "uint16"},
    "store": {"StoreID": "uint16", "RegionID": "uint16"},
    "region": {"RegionID": "uint16"},
    "product": {"ProductID": "uint16"},
}


def mssql_engine():
    odbc = (
        "DRIVER={ODBC Driver 18 for SQL Server};"
        f"SERVER={os.getenv('MSSQL_HOST', 'localhost')},{os.getenv('MSSQL_PORT', '14333')};"
        f"DATABASE={os.getenv('MSSQL_DB', 'RetailUZ')};UID=sa;PWD={os.environ['MSSQL_SA_PASSWORD']};"
        "TrustServerCertificate=yes;Encrypt=yes"
    )
    return sa.create_engine(f"mssql+pyodbc:///?odbc_connect={quote_plus(odbc)}")


def ch_client():
    return clickhouse_connect.get_client(
        host=os.getenv("CLICKHOUSE_HOST", "localhost"),
        port=int(os.getenv("CLICKHOUSE_HTTP_PORT", "8123")),
        username=os.getenv("CLICKHOUSE_USER", "default"),
        password=os.getenv("CLICKHOUSE_PASSWORD", ""),
        database=os.getenv("CLICKHOUSE_DB", "retailuz"),
    )


def ensure_schema(ch):
    sql = (ROOT / "sql" / "clickhouse" / "01_schema.sql").read_text(encoding="utf-8")
    body = "\n".join(l for l in sql.splitlines() if not l.strip().startswith("--"))
    for stmt in filter(None, (s.strip() for s in body.split(";"))):
        ch.command(stmt)


def prepare(df: pd.DataFrame, table: str) -> pd.DataFrame:
    df = df.astype(DTYPES.get(table, {}))
    if "SaleDate" in df:
        df["SaleDate"] = pd.to_datetime(df["SaleDate"]).dt.date
    return df


def load_table(src, ch, table, query, incremental=False):
    t0 = time.perf_counter()
    if incremental and table == "sales":
        max_id = ch.query("SELECT max(SaleID) FROM sales").result_rows[0][0] or 0
        query += f" WHERE SaleID > {int(max_id)}"
        print(f"  sales: incremental from SaleID > {max_id}")
    else:
        ch.command(f"TRUNCATE TABLE IF EXISTS {table}")

    n = 0
    with src.connect() as conn:
        for chunk in pd.read_sql(sa.text(query), conn, chunksize=CHUNK):
            if chunk.empty:
                continue
            ch.insert_df(table, prepare(chunk, table))
            n += len(chunk)
    print(f"  {table:<8} {n:>8} rows  {time.perf_counter() - t0:6.2f}s")


def validate(src, ch):
    print("\nValidation (SQL Server vs ClickHouse):")
    ok = True
    with src.connect() as conn:
        for table in TABLES:
            mssql_n = conn.execute(sa.text(f"SELECT COUNT(*) FROM dbo.{table}")).scalar()
            ch_n = ch.query(f"SELECT count() FROM {table} FINAL" if table != "sales"
                            else "SELECT count() FROM sales").result_rows[0][0]
            mark = "OK " if mssql_n == ch_n else "DIFF"
            ok &= mssql_n == ch_n
            print(f"  [{mark}] {table:<8} mssql={mssql_n:<8} clickhouse={ch_n}")
        mssql_sum = conn.execute(sa.text("SELECT SUM(Amount) FROM dbo.Sales")).scalar()
    ch_sum = ch.query("SELECT sum(Amount) FROM sales").result_rows[0][0]
    mark = "OK " if mssql_sum == ch_sum else "DIFF"
    ok &= mssql_sum == ch_sum
    print(f"  [{mark}] SUM(Amount) mssql={mssql_sum} clickhouse={ch_sum}")
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--incremental", action="store_true", help="append only new sales rows")
    args = ap.parse_args()

    src, ch = mssql_engine(), ch_client()
    print(f"ClickHouse {ch.server_version} -> database '{ch.database}'")
    ensure_schema(ch)

    print("Loading:")
    for table, query in TABLES.items():
        load_table(src, ch, table, query, incremental=args.incremental)

    ok = validate(src, ch)
    print("\nLOAD OK" if ok else "\nLOAD HAS DIFFERENCES")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
