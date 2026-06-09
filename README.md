# YugabyteDB 3-Node Demo Cluster

Spin up a local 3-node YugabyteDB cluster with Docker and explore distributed SQL concepts hands-on.

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (running)
- `psql` or `ysqlsh` client — `brew tap yugabyte/tap && brew install yugabyte-client` (recommended)
  - Without a local client, the Makefile falls back to `ysqlsh` inside the container automatically

## Quick Start

**Local Docker** (macOS/Linux with Docker Desktop):

```bash
git clone https://github.com/vickyharp/yb-3node-demo.git
cd yb-3node-demo
make up
```

`make up` starts the cluster and waits until all 3 nodes are alive (~90 seconds). You should see `✅ Cluster ready — 3 nodes alive`, then open any of the UIs below or run `make connect`.

**GitHub Codespaces** (no local Docker required): see [Devcontainer / GitHub Codespaces](#devcontainer--github-codespaces).

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

Run `make help` for the same list with descriptions.

```
make up              Start the 3-node cluster and wait until ready
make wait            Wait for cluster with progress and timeout
make show            Print connection info when cluster is ready
make diagnose        Print cluster connectivity diagnostics
make down            Stop the cluster (data volumes kept)
make clean           Stop the cluster AND delete all data volumes
make restart         Full restart (keeps data)
make status          Show yugabyted status for all nodes
make servers         List YB servers visible to YSQL
make logs            Tail live logs from all three nodes (Ctrl+C to exit)
make collect-logs    Snapshot logs to logs/ [NOTE="reason"]
make connect         Open an interactive YSQL shell
make shell           Open a shell on node 1 (yugabyted, yb-admin, etc.)
make sql Q="…"       Run an inline SQL statement
make demo F=…        Run a .sql file from demos/ (local, gitignored)
make kill N=2        Pause a node to simulate failure
make revive N=2      Restart a paused node
make repair-node N=3 Wipe and recreate a node (fixes OOM 137)
```

## Running SQL workloads

Put your own `.sql` files in `demos/` (gitignored) and run them against the cluster:

```bash
make demo F=demos/my-workload.sql
```

If you have a local `demos/range-to-hash-sharding.sql`, `make range-to-hash` runs that file directly.

**Northwind sample database** (optional): from a shell on node 1, load Yugabyte’s built-in demo:

```bash
make shell
/home/yugabyte/bin/yugabyted demo connect    # loads yb_demo_northwind and opens ysqlsh
/home/yugabyte/bin/yugabyted demo destroy    # remove when done
```

## Stopping the Cluster

```bash
make down    # stop, keep data volumes
make clean   # stop AND delete all data
```

> **Warning:** `make clean` deletes all named volumes. Any data written during demos will be lost.

## Troubleshooting

**Port 7000 already in use (macOS)**

On macOS Monterey and later, AirPlay Receiver binds to port 7000, conflicting with the YB-Master UI. Go to **System Settings → General → AirDrop & Handoff → AirPlay Receiver** and toggle it off, then retry.

**Node exits with code 137 (OOM)**

Exit code **137** means the Linux OOM killer stopped the container — common on
Codespaces when all three Yugabyte nodes boot at once on a small machine. Node 3
is hit most often.

**Prevention:** use a **8 GB+ RAM** Codespace (or local Docker with enough free
memory). The compose files start nodes sequentially (1 → 2 → 3) to reduce peak
RAM, but three nodes still need substantial memory.

**Recovery:**

```bash
make repair-node N=3
make wait
```

Or manually:

```bash
bash scripts/compose.sh ps -a    # confirm Exited (137)
bash scripts/repair-node.sh 3
make wait
```

**Node missing from `yb_servers()` (other causes)**

Inspect and try a simple restart first:

```bash
bash scripts/compose.sh ps -a
bash scripts/compose.sh logs yb-node3 --tail 50
bash scripts/compose.sh restart yb-node3
```

If `compose.sh ps -a` is empty but the cluster responds to ysqlsh, the running
containers use a different Compose project name — `compose.sh` auto-detects
that from container labels. You can also list them directly:

```bash
docker ps -a --filter label=com.docker.compose.service=yb-node1
```

---

## Devcontainer / GitHub Codespaces

The `.devcontainer/` folder starts a 3-node cluster automatically when the environment comes up. Startup **blocks until all 3 nodes appear in `yb_servers()`** (or times out after 10 minutes). Use `make show`, `make diagnose`, or `make wait` anytime.

Optionally copy `.devcontainer/.env.example` to `.devcontainer/.env` and set your git identity for commits inside the container (the `.env` file is gitignored and not required for Codespaces).

### Create a Codespace

On GitHub, open this repo → **Code** → **Codespaces** → **Create codespace on main**.

Use a machine type with **8 GB+ RAM** if you can — three Yugabyte nodes need substantial memory on small VMs (see [Node exits with code 137 (OOM)](#node-exits-with-code-137-oom) in Troubleshooting).

### Connect with VS Code

VS Code has native Codespaces support:

1. Install the [GitHub Codespaces](https://marketplace.visualstudio.com/items?itemName=GitHub.codespaces) extension (often bundled).
2. **Cmd/Ctrl+Shift+P** → **Codespaces: Connect to Codespace** (or click **Code → Open with Codespaces** on github.com).
3. Pick your codespace and open the **`/workspace`** folder when prompted.

Ports **5433** (YSQL), **15433** (yugabyted UI), **7000**, and **9000** are forwarded automatically while VS Code is connected.

For **local Docker** (not Codespaces): clone the repo, open it in VS Code, then **Reopen in Container** from the command palette.

### Connect with Cursor

Cursor does not include VS Code’s Codespaces UI. Connect via **Remote-SSH** and the GitHub CLI instead.

**One-time setup on your machine:**

```bash
brew install gh          # macOS; or see https://cli.github.com/
gh auth login
gh auth refresh -h github.com -s codespace
```

Install Cursor’s **Remote - SSH** extension (`anysphere.remote-ssh`) if it is not already present.

**Each codespace (or after a rebuild):**

```bash
gh codespace list
gh codespace ssh --config -c YOUR-CODESPACE-NAME >> ~/.ssh/config
```

If you have several codespaces, use `-c` to append config for just the one you want. Without `-c`, `gh codespace ssh --config` prints a block for every codespace — pick the matching `Host cs.…` entry in Cursor.

**Connect:**

1. **Cmd/Ctrl+Shift+P** → **Remote-SSH: Connect to Host…**
2. Choose your codespace host (e.g. `cs.quizzical-zebra-…` from `gh codespace ssh --config`)
3. Open **`/workspace`**

The devcontainer includes an SSH server (`sshd` feature) so this works. After changing `.devcontainer/`, **rebuild the codespace** before retrying.

**Port forwarding:** unlike VS Code’s native Codespaces connection, Cursor **does not** automatically forward cluster ports to your laptop. You can still use the cluster from Cursor’s **integrated terminal** (`make connect`, `ysqlsh -h yb-node1 …`). For tools on your **local machine** (GUI clients, a second terminal outside Cursor), open a tunnel separately — see [Open an SSH tunnel for YSQL](#open-an-ssh-tunnel-for-ysql-port-5433) below, or add `LocalForward` lines to the `Host cs.…` block in `~/.ssh/config`:

```
Host cs.YOUR-CODESPACE-NAME
  # … gh-generated ProxyCommand / User lines …
  LocalForward 5433 127.0.0.1:5433
  LocalForward 15433 127.0.0.1:15433
  LocalForward 7000 127.0.0.1:7000
  LocalForward 9000 127.0.0.1:9000
```

Reconnect in Cursor after editing `~/.ssh/config`. Use a different local port (e.g. `5434`) if 5433 is already in use on your machine.


### Connect from your local machine

The cluster inside a Codespace is **not** directly reachable from your laptop over the internet. You need an active **SSH tunnel** first. The `https://…-5433.app.github.dev` URL GitHub shows in the browser is an HTTP proxy — not a database connection. YSQL clients need **TCP to `localhost`** through a tunnel.

#### Open an SSH tunnel for YSQL (port 5433)

Use this when you want `ysqlsh`, `psql`, a GUI SQL client, or an app on your **laptop** to talk to the cluster. Required for **Cursor** users (Remote-SSH does not auto-forward ports). Also use this if you are **not** connected via VS Code’s Codespaces integration.

**Prerequisites:** [GitHub CLI](https://cli.github.com/) installed and authenticated (`gh auth login`, then `gh auth refresh -h github.com -s codespace`). Your Codespace must be running (`gh codespace list`).

**Step 1 — find the codespace name:**

```bash
gh codespace list
```

Copy the **NAME** column (e.g. `quizzical-zebra-v96wqpE5npQ6w56`).

**Step 2 — open the tunnel** (pick one method; leave the terminal running):

**Option A — `gh codespace ports forward`** (simplest):

```bash
gh codespace ports forward 5433:5433 -c YOUR-CODESPACE-NAME
```

Maps **your laptop’s port 5433** → **YSQL port 5433 inside the Codespace**. If local 5433 is already in use (e.g. you have a local cluster running), pick another local port:

```bash
gh codespace ports forward 5434:5433 -c YOUR-CODESPACE-NAME
```

**Option B — SSH local port forward:**

```bash
gh codespace ssh -c YOUR-CODESPACE-NAME -L 5433:localhost:5433 -N
```

`-N` keeps the session open without a shell. Same local-port workaround: use `-L 5434:localhost:5433` if 5433 is busy on your machine.

**Step 3 — connect your tool** (in a **second** terminal or your GUI client):

```bash
ysqlsh -h localhost -p 5433 -U yugabyte
psql -h localhost -p 5433 -U yugabyte -d yugabyte
```

Use port **5434** (or whatever local port you chose) if you forwarded to a non-default port.

**Other ports** use the same pattern — forward first, then hit `localhost`:

| Port  | Service        | Forward example |
|-------|----------------|-----------------|
| 5433  | YSQL           | `gh codespace ports forward 5433:5433 -c NAME` |
| 15433 | yugabyted UI   | `gh codespace ports forward 15433:15433 -c NAME` |
| 7000  | YB-Master UI   | `gh codespace ports forward 7000:7000 -c NAME` |
| 9000  | YB-TServer UI  | `gh codespace ports forward 9000:9000 -c NAME` |

**Connection parameters** (after the tunnel is up):

| Setting  | Value |
|----------|-------|
| Host     | `localhost` |
| Port     | `5433` (or your chosen local port) |
| Database | `yugabyte` |
| Username | `yugabyte` |
| Password | *(leave blank)* |

JDBC-style URL (for Java-based clients): `jdbc:postgresql://localhost:5433/yugabyte`

#### Via VS Code (no manual tunnel)

If VS Code is connected through the **GitHub Codespaces** extension, it forwards ports from `devcontainer.json` automatically. Use the same `localhost:5433` settings above. Confirm port **5433** appears in the **Ports** panel (the local port may differ if 5433 is already in use locally — use whatever the panel shows).

**Cursor** does not get this behavior — use the [SSH tunnel steps](#open-an-ssh-tunnel-for-ysql-port-5433) or `LocalForward` in `~/.ssh/config` (see [Connect with Cursor](#connect-with-cursor)).

#### Local Docker (no Codespace)

Run `make up` locally and use `localhost:5433` — no SSH or port forwarding needed.

### Codespaces troubleshooting

**Devcontainer / Codespaces startup hangs**

```bash
make show        # print URLs and current node count anytime
make diagnose    # snapshot if something is stuck
make wait        # run the wait again manually
```

Override the timeout with `CLUSTER_WAIT_TIMEOUT=300 make wait`.

If the UIs on ports 7000/15433 look healthy but `make wait` hangs, YSQL may still be catching up — or a node is missing from `yb_servers()` (check with `make diagnose`).

**Cursor: “Please check if an SSH server is installed in the container”**

Rebuild the codespace so the `sshd` devcontainer feature is applied, then refresh SSH config with `gh codespace ssh --config -c YOUR-CODESPACE-NAME`.

**`docker: command not found` in the devcontainer**

Rebuild the container — the devcontainer image mounts the Docker socket and installs the CLI. Until then, YSQL still works:

```bash
ysqlsh -h yb-node1 -p 5433 -U yugabyte
```

**Node exits with code 137 (OOM)** — see [Troubleshooting → Node exits with code 137](#node-exits-with-code-137-oom) above.

