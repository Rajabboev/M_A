#!/usr/bin/env bash
# Installs, inside the ClickHouse (Ubuntu 22.04) image/container:
#   1) unixODBC
#   2) Microsoft ODBC Driver 18 for SQL Server (msodbcsql18) + mssql-tools18 (sqlcmd, for testing)
#   3) clickhouse-odbc-bridge 25.1.5.31 (last published build; required for odbc() / ODBC engine)
#
# Used by docker/clickhouse/Dockerfile. Can also be run in a live container (lost on recreate):
#   docker cp docker/clickhouse/install_odbc.sh ma_clickhouse:/tmp/ && docker exec ma_clickhouse bash /tmp/install_odbc.sh
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive ACCEPT_EULA=Y

. /etc/os-release                                   # VERSION_ID=22.04
CH_VER="$(clickhouse local --version | grep -oE '[0-9]+(\.[0-9]+){3}')"
echo ">> Ubuntu ${VERSION_ID}, ClickHouse ${CH_VER}"

apt-get update
apt-get install -y --no-install-recommends curl ca-certificates gnupg apt-transport-https unixodbc

# --- Microsoft repo + msodbcsql18 ---
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/ubuntu/${VERSION_ID}/prod ${VERSION_CODENAME} main" \
  > /etc/apt/sources.list.d/mssql-release.list
apt-get update
apt-get install -y --no-install-recommends msodbcsql18 mssql-tools18

# --- clickhouse-odbc-bridge ---
# ClickHouse stopped publishing the bridge after 25.1 (no 25.2+ deb/tgz exists), so we install the
# last released standalone bridge. It is a separate process the server talks to over HTTP.
BRIDGE_VER="${BRIDGE_VER:-25.1.5.31}"
curl -fsSL "https://packages.clickhouse.com/tgz/stable/clickhouse-odbc-bridge-${BRIDGE_VER}-amd64.tgz" -o /tmp/bridge.tgz
tar -xzf /tmp/bridge.tgz -C /tmp
install -m 0755 "$(find /tmp -path '*usr/bin/clickhouse-odbc-bridge' -type f | head -1)" /usr/bin/clickhouse-odbc-bridge
rm -rf /tmp/bridge.tgz /tmp/clickhouse-odbc-bridge-*

apt-get clean && rm -rf /var/lib/apt/lists/*

echo ">> installed ODBC drivers:"; odbcinst -q -d
echo ">> bridge: $(command -v clickhouse-odbc-bridge)"
