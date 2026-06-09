#!/usr/bin/env bash
set -euo pipefail

NODE=${1:?Usage: revive-node.sh <1|2|3>}

echo "🟢 Starting yb-node${NODE}..."
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
docker compose --project-directory "${REPO_ROOT}" start yb-node${NODE}
echo "   Node ${NODE} is rejoining the cluster and syncing its WAL."
