-- W15: give the M_A user (VS Code "ClickHouse_Admin" connection) access to retailuz
-- Run:  docker exec -i ma_clickhouse clickhouse-client --multiquery < sql/clickhouse/02_grants.sql

GRANT SELECT, INSERT, ALTER, CREATE TABLE, DROP TABLE, TRUNCATE, SHOW ON retailuz.* TO M_A;
