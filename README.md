# YugabyteDB 3-Node Demo Cluster

Spin up a local 3-node YugabyteDB cluster with Docker and explore distributed SQL concepts hands-on.

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (running)
- `psql` or `ysqlsh` client — `brew tap yugabyte/tap && brew install yugabyte-client` (recommended)
  - Without a local client, the Makefile falls back to `ysqlsh` inside the container automatically

## Quick Start

```bash
git clone https://github.com/<your-org>/yb-3node-demo.git
cd yb-3node-demo
make up
```

Wait for `✅ Cluster ready — 3 nodes alive` (~90 seconds), then open any of the UIs below or run `make connect`.

## Cluster Architecture

The cluster runs **3 YugabyteDB nodes** with Replication Factor 3 (RF=3). Every piece of data is replicated to all three nodes using the **Raft consensus protocol**. A write is only acknowledged after 2 of 3 nodes confirm it (a quorum), so the cluster can tolerate the loss of one node without losing data or availability.

Each node runs both a YB-Master (metadata management) and a YB-TServer (data storage and queries). The nodes communicate over an internal Docker network (`yb-net`).

Data is persisted in Docker volumes mounted at `/root/var` on each node, so `make down` / `make up` keeps your databases. Only `make clean` wipes data.

## Useful Ports

| Port  | Service | URL |
|-------|---------|-----|
| 15433 | yugabyted UI (cluster overview, metrics, query editor) | http://localhost:15433 |
| 7000  | YB-Master HTTP UI (tablet distribution, Raft leaders) | http://localhost:7000 |
| 9000  | YB-TServer HTTP UI (per-node tablet stats) | http://localhost:9000 |
| 5433  | YSQL (PostgreSQL wire protocol) | `ysqlsh -h localhost -p 5433 -U yugabyte` |

## Available Commands

```
make up              Start the 3-node cluster (detached)
make down            Stop the cluster (data volumes kept)
make clean           Stop the cluster AND delete all data volumes
make restart         Full restart (keeps data)
make status          Show yugabyted status for all nodes
make servers         List YB servers visible to YSQL
make logs            Tail live logs from all three nodes
make collect-logs    Snapshot logs to logs/ [NOTE="reason"]
make connect         Open an interactive YSQL shell
make sql Q="…"       Run an inline SQL statement
make demo F=…        Run a .sql file from demos/ (local, gitignored)
make kill N=2        Pause a node to simulate failure
make revive N=2      Restart a paused node
```

## Running SQL workloads

Put your own `.sql` files in `demos/` (gitignored) and run them against the cluster:

```bash
make demo F=demos/my-workload.sql
```

If you have a local `demos/range-to-hash-sharding.sql`, `make range-to-hash` runs that file directly.

## Stopping the Cluster

```bash
make down    # stop, keep data volumes
make clean   # stop AND delete all data
```

> **Warning:** `make clean` deletes all named volumes. Any data written during demos will be lost.

## Troubleshooting

**Port 7000 already in use (macOS)**

On macOS Monterey and later, AirPlay Receiver binds to port 7000, conflicting with the YB-Master UI. Go to **System Settings → General → AirDrop & Handoff → AirPlay Receiver** and toggle it off, then retry.

**Node 3 fails to start on first boot**

If `make up` hangs waiting for 3 nodes, check `docker compose ps`. A node that exited with code 137 can usually be recovered with `docker compose start yb-node3`.

---

### VS Code Devcontainer

The `.devcontainer/` folder is for VS Code / Cursor users. Open the folder and choose **Reopen in Container** to get a pre-configured dev environment with the cluster started automatically.

Copy `.devcontainer/.env.example` to `.devcontainer/.env` and set your git identity (the `.env` file is gitignored).
