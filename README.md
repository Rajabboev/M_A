# M_A — Data Warehouse & BI Engineering (W13–W22)

The local environment for the hybrid track. **W13: Linux, Docker, Git + Python (pandas, SQL connection).**

## Layout
```
M_A/
├── docker-compose.yml     # local stack (SQL Server 2022 in Docker, port 14333)
├── .env / .env.example    # credentials & ports (.env is git-ignored)
├── requirements.txt       # Python: pandas, sqlalchemy, pyodbc, jupyterlab…
├── sql/init/              # auto-run seed scripts (RetailUZ demo DB)
├── scripts/check_env.py   # end-to-end environment check
├── notebooks/             # lesson notebooks
├── data/                  # CSV/Excel files (mounted at /data in the container)
└── weeks/W13/             # lesson materials
```

## Quick start
```powershell
cd $HOME\Desktop\M_A
docker compose up -d                      # start SQL Server + seed RetailUZ
docker compose ps                         # sqlserver should be "healthy"
.\.venv\Scripts\python scripts\check_env.py
.\.venv\Scripts\jupyter lab               # kernel: "Python (M_A)"
```

## Connection details
| | Docker SQL Server | Native SQL Server (host) |
|---|---|---|
| Server | `localhost,14333` | `localhost` (default instance) |
| Login | `sa` / password in `.env` | Windows auth |
| DB | `RetailUZ` (demo seed) | — |

SSMS/Azure Data Studio: Server = `localhost,14333`, SQL Login `sa`, tick **Trust server certificate**.

## Useful commands (Linux/Docker demo)
```powershell
docker exec -it ma_sqlserver bash                          # Linux shell in the container
docker exec -it ma_sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -C   # sqlcmd
docker compose logs -f sqlserver
docker compose down        # stop (data kept)
docker compose down -v     # stop + DELETE data (re-seeds on next up)
```

## Later weeks
ClickHouse + Superset (W15), dbt (W17), and Airflow (W19) get added to `docker-compose.yml` as new services when those weeks start.
