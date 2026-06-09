#!/usr/bin/env bash
set -euo pipefail

NODE=${1:?Usage: kill-node.sh <1|2|3>}

echo "🔴 Stopping yb-node${NODE}..."
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
docker compose --project-directory "${REPO_ROOT}" stop yb-node${NODE}
echo "   Node ${NODE} is down. Cluster has 2/3 nodes alive (quorum maintained)."
