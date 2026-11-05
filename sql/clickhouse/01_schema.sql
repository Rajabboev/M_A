-- W15: RetailUZ target schema in ClickHouse (mirrors SQL Server dbo.* tables)
-- Run:  docker exec -i ma_clickhouse clickhouse-client --multiquery < sql/clickhouse/01_schema.sql
-- Idempotent: safe to re-run.

CREATE DATABASE IF NOT EXISTS retailuz;

-- Dimensions: small tables -> ReplacingMergeTree keyed by the business ID,
-- so re-loading the same row replaces it instead of duplicating it.
CREATE TABLE IF NOT EXISTS retailuz.region
(
    RegionID    UInt16,
    RegionName  LowCardinality(String)
)
ENGINE = ReplacingMergeTree
ORDER BY RegionID;

CREATE TABLE IF NOT EXISTS retailuz.store
(
    StoreID     UInt16,
    StoreName   String,
    RegionID    UInt16
)
ENGINE = ReplacingMergeTree
ORDER BY StoreID;

CREATE TABLE IF NOT EXISTS retailuz.product
(
    ProductID   UInt16,
    ProductName String,
    Category    LowCardinality(String),
    UnitPrice   Decimal(12, 2)            -- UZS
)
ENGINE = ReplacingMergeTree
ORDER BY ProductID;

-- Fact: MergeTree, monthly partitions, sorted for date/store/product filters
CREATE TABLE IF NOT EXISTS retailuz.sales
(
    SaleID      UInt32,
    SaleDate    Date,
    StoreID     UInt16,
    ProductID   UInt16,
    Qty         UInt16,
    Amount      Decimal(14, 2)
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(SaleDate)
ORDER BY (SaleDate, StoreID, ProductID)
SETTINGS index_granularity = 8192;
