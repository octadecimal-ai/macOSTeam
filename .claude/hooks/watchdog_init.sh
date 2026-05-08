#!/usr/bin/env bash
set -euo pipefail

# Wiedza architektoniczna:
# - Hooki projektu są deterministyczną warstwą egzekwowania zasad.
# - Inicjalizacja watchdoga powinna zajść przy SessionStart.

mkdir -p .claude/runtime
touch .claude/runtime/watchdog_violations.ndjson
touch .claude/runtime/watchdog.log
touch .claude/runtime/watchdog_state.env

if [[ ! -f .claude/runtime/watchdog_state.env ]] || ! rg -q "^ESCALATION_LEVEL=" .claude/runtime/watchdog_state.env; then
  cat > .claude/runtime/watchdog_state.env <<'EOF'
ESCALATION_LEVEL=0
EOF
fi

echo "[$(date -Iseconds)] Watchdog zainicjalizowany." >> .claude/runtime/watchdog.log

.claude/hooks/watchdog_snapshot.sh "WatchdogInit" "Inicjalizacja watchdoga i plików stanu."
