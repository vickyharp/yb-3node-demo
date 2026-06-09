#!/usr/bin/env bash
set -euo pipefail

COMPOSE="docker compose"

echo '⏳ Waiting for YugabyteDB cluster...'

# Prefer local psql (native + fast); fall back to docker exec ysqlsh
if command -v psql >/dev/null 2>&1; then
  check() { psql -h localhost -p 5433 -U yugabyte -tAc "SELECT count(*) FROM yb_servers()" 2>/dev/null | grep -q '^3$'; }
else
  check() { $COMPOSE exec -T yb-node1 /home/yugabyte/bin/ysqlsh -h yb-node1 -p 5433 -U yugabyte \
              -tAc "SELECT count(*) FROM yb_servers()" 2>/dev/null | grep -q '^3$'; }
fi

until check; do
  sleep 3
done

echo '⚙️  Configuring data placement (RF=3, fault_tolerance=zone)...'
docker compose exec -T yb-node1 /home/yugabyte/bin/yugabyted configure data_placement \
  --fault_tolerance=zone 2>/dev/null || true

echo '✅ Cluster ready — 3 nodes alive'
echo ''
echo '   yugabyted UI → http://localhost:15433'
echo '   Master UI    → http://localhost:7000'
echo '   TServer UI   → http://localhost:9000'
echo '   Connect      → make connect'
echo '   Help         → make help'
