-- W15: load RetailUZ from SQL Server into ClickHouse with pure SQL via odbc() — no Python.
-- ClickHouse -> clickhouse-odbc-bridge -> ODBC Driver 18 -> SQL Server (service "sqlserver", DSN in docker/clickhouse/odbc.ini)
--
-- Run (password stays inside the container, read from its MSSQL_SA_PASSWORD env var):
--   Get-Content sql\clickhouse\03_load_from_mssql_odbc.sql | docker exec -i ma_clickhouse bash -c 'clickhouse-client --multiquery --param_mssql="DSN=mssql_retailuz;UID=sa;PWD={$MSSQL_SA_PASSWORD}"'
--
-- {mssql:String} is a query parameter = the ODBC connection string. PWD is wrapped in {} because it contains '!'.
-- Type notes: SQL Server DECIMAL arrives as String, DATE as DateTime, INT as Int32 -> cast explicitly.
-- Requires 01_schema.sql to have been run.

-- Dimensions: full reload
TRUNCATE TABLE IF EXISTS retailuz.region;
INSERT INTO retailuz.region
SELECT toUInt16(RegionID), RegionName
FROM odbc({mssql:String}, 'dbo', 'Region');

TRUNCATE TABLE IF EXISTS retailuz.store;
INSERT INTO retailuz.store
SELECT toUInt16(StoreID), StoreName, toUInt16(RegionID)
FROM odbc({mssql:String}, 'dbo', 'Store');

TRUNCATE TABLE IF EXISTS retailuz.product;
INSERT INTO retailuz.product
SELECT toUInt16(ProductID), ProductName, Category, toDecimal64(UnitPrice, 2)
FROM odbc({mssql:String}, 'dbo', 'Product');

-- Fact: full reload. For incremental, replace TRUNCATE with:
--   WHERE SaleID > (SELECT max(SaleID) FROM retailuz.sales)
TRUNCATE TABLE IF EXISTS retailuz.sales;
INSERT INTO retailuz.sales
SELECT toUInt32(SaleID), toDate(SaleDate), toUInt16(StoreID), toUInt16(ProductID),
       toUInt16(Qty), toDecimal64(Amount, 2)
FROM odbc({mssql:String}, 'dbo', 'Sales');

-- Validation: source vs target
SELECT 'sales'   AS tbl, (SELECT count() FROM odbc({mssql:String}, 'dbo', 'Sales'))   AS mssql, (SELECT count() FROM retailuz.sales)   AS clickhouse
UNION ALL
SELECT 'product', (SELECT count() FROM odbc({mssql:String}, 'dbo', 'Product')), (SELECT count() FROM retailuz.product)
UNION ALL
SELECT 'store',   (SELECT count() FROM odbc({mssql:String}, 'dbo', 'Store')),   (SELECT count() FROM retailuz.store)
UNION ALL
SELECT 'region',  (SELECT count() FROM odbc({mssql:String}, 'dbo', 'Region')),  (SELECT count() FROM retailuz.region)
FORMAT PrettyCompact;

SELECT (SELECT sum(toDecimal64(Amount, 2)) FROM odbc({mssql:String}, 'dbo', 'Sales')) AS mssql_amount,
       (SELECT sum(Amount) FROM retailuz.sales)                                       AS clickhouse_amount
FORMAT PrettyCompact;
