# Replay Lab — both proxymock workflows on the banking transactions-service.
#
# proxymock replays REAL captured production traffic against the service and mocks
# every downstream dependency from REAL recorded traffic. Postgres is the only live
# dependency (see setup.sh). Logic lives in the *.sh scripts so the commands work the
# same by hand or under make.
#
# Workflow A — release gate (catch it BEFORE prod):
#   Terminal 1:  make run MEMO_BUG=false                     # prod build
#   Terminal 2:  make gate                                   # GREEN: 100% match
#   Terminal 1:  make run MEMO_BUG=false CONTRACT_REFACTOR=true   # agent's build
#   Terminal 2:  make gate                                   # RED: blocked pre-merge
#
# Workflow B — reproduce a live prod issue (fix it FAST):
#   Terminal 1:  make run         # service + proxymock mock (deps), bug armed
#   Terminal 2:  make reproduce   # replay the captured prod failure  -> RED  (400)
#                make fix         # apply the agent's fix, replay      -> GREEN (201)
#
SHELL := /bin/bash
SVC   := backend/transactions-service/src/main/java/com/banking/transactionsservice/service/TransactionService.java
PORT  ?= 8087
export PORT
# flags for run.sh/reproduce.sh; empty means "use the script default"
export MEMO_BUG CONTRACT_REFACTOR MOCKS IN

.PHONY: help setup run reproduce fix reset down gate record-suite incident
help: ## list targets
	@grep -hE '^[a-z-]+:.*##' $(MAKEFILE_LIST) | sed 's/:.*##/\t/' | column -t -s "$$(printf '\t')"

setup: ## one-time prereqs: postgres + db user + build (single script)
	@./setup.sh

run: ## terminal 1: proxymock mock (deps) + the service; flags: MEMO_BUG, CONTRACT_REFACTOR
	@./run.sh

gate: ## release gate: replay prod-suite/ against the running build; exit code = verdict
	@./gate.sh

record-suite: ## re-record prod-suite/ from the running CLEAN build (make run MEMO_BUG=false)
	@./record-suite.sh

incident: ## pull the live failing traffic from the replay-lab BYOC export + craft mocks
	@./incident.sh

reproduce: ## terminal 2: replay the captured prod failure against the service
	@./reproduce.sh

fix: ## apply the agent's fix (fix.patch), hot-restart, replay -> GREEN
	@./fix.sh

reset: ## revert the fix (back to the bug)
	@cd .. && git checkout -- $(SVC) && echo ">> reverted to the buggy version"

down: ## stop the service + mock (leaves postgres up)
	@pkill -f "spring-boot:run" 2>/dev/null; pkill -f "proxymock mock" 2>/dev/null; true
	@echo "stopped (postgres left running; 'docker compose stop postgres' to stop it too)"
