# Replay Lab — local reproduce/fix loop for the banking deposit bug.
#
# proxymock replays a REAL captured production request against the service and mocks
# every downstream dependency from REAL recorded traffic. Postgres is the only live
# dependency (see setup.sh). Logic lives in the *.sh scripts so the commands work the
# same by hand or under make.
#
#   Terminal 1:  make run         # service + proxymock mock (deps), bug armed
#   Terminal 2:  make reproduce   # replay the captured prod failure  -> RED  (400)
#                make fix         # apply the agent's fix, replay      -> GREEN (201)
#
SHELL := /bin/bash
SVC   := backend/transactions-service/src/main/java/com/banking/transactionsservice/service/TransactionService.java
PORT  ?= 8080
export PORT

.PHONY: help setup run reproduce fix reset down
help: ## list targets
	@grep -hE '^[a-z-]+:.*##' $(MAKEFILE_LIST) | sed 's/:.*##/\t/' | column -t -s "$$(printf '\t')"

setup: ## one-time prereqs: postgres + db user + build (single script)
	@./setup.sh

run: ## terminal 1: proxymock mock (deps) + the service, bug armed
	@./run.sh

reproduce: ## terminal 2: replay the captured prod failure against the service
	@./reproduce.sh

fix: ## apply the agent's fix (fix.patch), hot-restart, replay -> GREEN
	@./fix.sh

reset: ## revert the fix (back to the bug)
	@cd .. && git checkout -- $(SVC) && echo ">> reverted to the buggy version"

down: ## stop the service + mock (leaves postgres up)
	@pkill -f "spring-boot:run" 2>/dev/null; pkill -f "proxymock mock" 2>/dev/null; true
	@echo "stopped (postgres left running; 'docker compose stop postgres' to stop it too)"
