COMPOSE     := bash scripts/compose.sh
YB_EXEC     := $(COMPOSE) exec -T yb-node1 /home/yugabyte/bin
YSQL_HOST   ?= $(shell bash scripts/resolve-ysql-host.sh)

# Use local ysqlsh if available (brew tap yugabyte/tap && brew install yugabyte-client), otherwise shell into the container
ifneq ($(shell command -v ysqlsh 2>/dev/null),)
YSQL        := ysqlsh -h $(YSQL_HOST) -p 5433 -U yugabyte
else
YSQL        := $(COMPOSE) exec -T yb-node1 /home/yugabyte/bin/ysqlsh -h yb-node1 -p 5433 -U yugabyte
endif

# Interactive variant (needs a tty)
ifneq ($(shell command -v ysqlsh 2>/dev/null),)
YSQL_TTY    := ysqlsh -h $(YSQL_HOST) -p 5433 -U yugabyte
# Run a .sql file on the host via native ysqlsh
run_sql_file = $(YSQL) -f $(1)
else
YSQL_TTY    := $(COMPOSE) exec yb-node1 /home/yugabyte/bin/ysqlsh -h yb-node1 -p 5433 -U yugabyte
# Pipe host file into ysqlsh inside the container
run_sql_file = cat $(1) | $(COMPOSE) exec -T yb-node1 /home/yugabyte/bin/ysqlsh -h yb-node1 -p 5433 -U yugabyte
endif

.DEFAULT_GOAL := help
.PHONY: help up down clean restart wait diagnose show status servers connect shell sql demo range-to-hash kill revive repair-node logs collect-logs ysqlsh-check

help: ## Show available commands
	@printf "\n\033[1mYugabyteDB 3-node demo cluster\033[0m\n\n"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'
	@printf "\n\033[90mTip: brew tap yugabyte/tap && brew install yugabyte-client   →   ysqlsh available natively on your Mac\033[0m\n\n"

# ── Cluster lifecycle ──────────────────────────────────────────────────────────

up: ## Start the 3-node cluster (detached)
	$(COMPOSE) up -d
	@bash scripts/wait-for-cluster.sh

down: ## Stop the cluster (data volumes kept)
	$(COMPOSE) down

clean: ## Stop the cluster AND delete all data volumes
	$(COMPOSE) down -v

restart: down up ## Full restart (keeps data)

wait: ## Wait for all 3 nodes (progress + timeout; use after devcontainer opens)
	@bash scripts/wait-for-cluster.sh

diagnose: ## Print cluster connectivity diagnostics
	@bash scripts/wait-for-cluster.sh --diagnose

show: ## Show cluster URLs and status (always works)
	@bash scripts/wait-for-cluster.sh --show

# ── Cluster inspection ─────────────────────────────────────────────────────────

status: ## Show yugabyted status for all nodes
	@for n in 1 2 3; do \
	  printf "\033[1m── node$$n ──\033[0m\n"; \
	  $(COMPOSE) exec yb-node$$n /home/yugabyte/bin/yugabyted status 2>/dev/null || true; \
	  echo; \
	done

servers: ## List YB servers visible to YSQL
	$(YSQL) -c "SELECT host, port, cloud, region, zone, node_type FROM yb_servers() ORDER BY host;"

logs: ## Tail live logs from all three nodes (Ctrl+C to exit)
	$(COMPOSE) logs -f yb-node1 yb-node2 yb-node3

collect-logs: ## Snapshot logs from all nodes: make collect-logs [NOTE="reason"]
	@bash scripts/collect-logs.sh "$(NOTE)"

# ── Query tools ────────────────────────────────────────────────────────────────

shell: ## Open a shell on node 1 (access yugabyted, yb-admin, etc.)
	$(COMPOSE) exec yb-node1 bash

connect: ysqlsh-check ## Open an interactive YSQL shell (Ctrl-D to exit)
	$(YSQL_TTY)

sql: ## Run an inline SQL statement: make sql Q="SELECT version();"
	@test -n "$(Q)" || (printf "Usage: make sql Q=\"<statement>\"\n"; exit 1)
	$(YSQL) -c "$(Q)"

demo: ## Run a .sql file: make demo F=demos/my-workload.sql
	@test -n "$(F)" || (printf "Usage: make demo F=demos/<file>.sql\n"; exit 1)
	$(call run_sql_file,$(F))

range-to-hash: ## Run the range-vs-hash sharding demo
	$(call run_sql_file,demos/range-to-hash-sharding.sql)

# ── Fault-injection ────────────────────────────────────────────────────────────

kill: ## Pause a node to simulate failure: make kill N=2
	@test -n "$(N)" || (printf "Usage: make kill N=<1|2|3>\n"; exit 1)
	@bash scripts/kill-node.sh $(N)

revive: ## Restart a paused node: make revive N=2
	@test -n "$(N)" || (printf "Usage: make revive N=<1|2|3>\n"; exit 1)
	@bash scripts/revive-node.sh $(N)

repair-node: ## Wipe and recreate a node (fixes exit 137 / bad state): make repair-node N=3
	@test -n "$(N)" || (printf "Usage: make repair-node N=<1|2|3>\n"; exit 1)
	@bash scripts/repair-node.sh $(N)

# ── Helpers ────────────────────────────────────────────────────────────────────

ysqlsh-check:
	@if ! command -v ysqlsh >/dev/null 2>&1; then \
	  printf "\033[90m ysqlsh not found — using ysqlsh inside container.\033[0m\n"; \
	  printf "\033[90mFor a native client: brew tap yugabyte/tap && brew install yugabyte-client\033[0m\n"; \
	fi
