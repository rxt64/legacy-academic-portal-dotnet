#!/usr/bin/env bash
# =====================================================================
# SIGEA - provision a LOCAL throwaway SQL Server for development/testing.
#
# Starts a SQL Server 2022 container (loopback only), creates the SIGEA
# database, the least-privilege logins, the schema and synthetic data.
# FOR LOCAL LAB USE ONLY. The passwords here are throwaway lab values that
# match db/accounts/00_create_logins.sql and guard only synthetic data on a
# loopback server. Never use them anywhere real.
#
# Requirements: docker. Usage:  ./scripts/provision-local-db.sh
# =====================================================================
set -euo pipefail

CONTAINER="${CONTAINER:-sigea-mssql}"
IMAGE="${IMAGE:-mcr.microsoft.com/mssql/server:2022-latest}"
SA_PW="${SA_PW:-LabRoot#2011pw}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Starting $CONTAINER (loopback 127.0.0.1:1433 only)"
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
docker run -d --name "$CONTAINER" \
  -e 'ACCEPT_EULA=Y' -e "MSSQL_SA_PASSWORD=$SA_PW" -e 'MSSQL_PID=Developer' \
  -p 127.0.0.1:1433:1433 "$IMAGE" >/dev/null

echo "==> Waiting for SQL Server to accept connections..."
until docker logs "$CONTAINER" 2>&1 | grep -q "SQL Server is now ready for client connections"; do
  sleep 3
done
sleep 2

SQLCMD="/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P $SA_PW -C"
echo "==> Copying SQL scripts into the container"
docker cp "$HERE/db" "$CONTAINER:/tmp/db" >/dev/null

echo "==> 00 create database + least-privilege logins (as sa)"
docker exec "$CONTAINER" bash -lc "$SQLCMD -i /tmp/db/accounts/00_create_logins.sql"
echo "==> 01 schema + grants"
docker exec "$CONTAINER" bash -lc "$SQLCMD -i /tmp/db/schema/01_schema.sql"
echo "==> 02 synthetic data"
docker exec "$CONTAINER" bash -lc "$SQLCMD -i /tmp/db/data/02_synthetic_data.sql"

echo
echo "Done. Connect (loopback only):"
echo "  app : Server=localhost;Database=SIGEA;User Id=sigea_app;Password=App#Lab2011"
echo "  lab : Server=localhost;Database=SIGEA;User Id=sigea_labro;Password=LabRo#Lab2011"
