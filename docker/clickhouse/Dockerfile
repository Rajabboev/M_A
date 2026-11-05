# W15: ClickHouse + Microsoft ODBC Driver 18 + clickhouse-odbc-bridge
# Lets ClickHouse read SQL Server directly:  SELECT * FROM odbc('DSN=mssql_retailuz;...', 'dbo', 'Sales')
ARG CH_VERSION=25.8
FROM clickhouse/clickhouse-server:${CH_VERSION}

COPY install_odbc.sh /tmp/install_odbc.sh
RUN bash /tmp/install_odbc.sh && rm /tmp/install_odbc.sh

# DSN definitions (no credentials inside — pass UID/PWD in the connection string)
COPY odbc.ini /etc/odbc.ini
