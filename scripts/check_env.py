"""W13 environment check: Python libs -> SQL Server (Docker) -> pandas round-trip.

Run:  .venv\\Scripts\\python scripts\\check_env.py
"""
import os
import sys
from pathlib import Path
from urllib.parse import quote_plus

from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[1]
load_dotenv(ROOT / ".env")

ok = True


def step(name, fn):
    global ok
    try:
        msg = fn()
        print(f"[ OK ] {name}" + (f" — {msg}" if msg else ""))
    except Exception as e:  # noqa: BLE001
        ok = False
        print(f"[FAIL] {name} — {type(e).__name__}: {e}")


print(f"Python {sys.version.split()[0]} @ {sys.executable}")

import pandas as pd
import pyodbc
import sqlalchemy as sa

step("libraries", lambda: f"pandas {pd.__version__}, sqlalchemy {sa.__version__}, pyodbc {pyodbc.version}")
step("ODBC Driver 18", lambda: "found" if "ODBC Driver 18 for SQL Server" in pyodbc.drivers()
     else (_ for _ in ()).throw(RuntimeError(f"drivers: {pyodbc.drivers()}")))

host = os.getenv("MSSQL_HOST", "localhost")
port = os.getenv("MSSQL_PORT", "14333")
db = os.getenv("MSSQL_DB", "RetailUZ")
pwd = os.environ["MSSQL_SA_PASSWORD"]

odbc = (
    "DRIVER={ODBC Driver 18 for SQL Server};"
    f"SERVER={host},{port};DATABASE={db};UID=sa;PWD={pwd};"
    "TrustServerCertificate=yes;Encrypt=yes"
)
engine = sa.create_engine(f"mssql+pyodbc:///?odbc_connect={quote_plus(odbc)}", fast_executemany=True)


def version():
    with engine.connect() as c:
        return c.execute(sa.text("SELECT @@VERSION")).scalar().splitlines()[0]


def read_sales():
    df = pd.read_sql(
        """SELECT r.RegionName, SUM(s.Amount) AS Revenue, COUNT(*) AS Orders
           FROM dbo.Sales s JOIN dbo.Store st ON st.StoreID = s.StoreID
           JOIN dbo.Region r ON r.RegionID = st.RegionID
           GROUP BY r.RegionName ORDER BY Revenue DESC""",
        engine,
    )
    print(df.to_string(index=False))
    return f"{len(df)} regions"


def write_roundtrip():
    df = pd.DataFrame({"id": [1, 2, 3], "name": ["a", "b", "c"]})
    df.to_sql("_env_check", engine, schema="dbo", if_exists="replace", index=False)
    n = pd.read_sql("SELECT COUNT(*) AS n FROM dbo._env_check", engine).n[0]
    with engine.begin() as c:
        c.execute(sa.text("DROP TABLE dbo._env_check"))
    return f"wrote+read {n} rows"


step(f"connect {host}:{port}/{db}", version)
step("pandas read_sql (RetailUZ)", read_sales)
step("pandas to_sql round-trip", write_roundtrip)

print("\nALL CHECKS PASSED" if ok else "\nSOME CHECKS FAILED")
sys.exit(0 if ok else 1)
