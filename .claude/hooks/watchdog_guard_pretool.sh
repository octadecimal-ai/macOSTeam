#!/usr/bin/env bash
set -euo pipefail

# Wiedza architektoniczna:
# - Hook PreToolUse może zablokować wykonanie narzędzi (deterministyczna bramka).
# - Przy eskalacji krytycznej praca zespołu jest zatrzymywana do interwencji człowieka.

.claude/hooks/watchdog_snapshot.sh "PreToolUse" "Kontrola blokady wykonania narzędzi."

if [[ -f ".claude/runtime/team-stop.flag" ]]; then
  echo "WATCHDOG STOP: Zespół zatrzymany. Wymagana interwencja człowieka/CEO." >&2
  exit 2
fi

# Zapisz czas startu subagenta (dla SubagentStop timer)
# CLAUDE_TOOL_NAME jest dostępny w środowisku hooka PreToolUse
if [[ "${CLAUDE_TOOL_NAME:-}" == "Agent" ]]; then
  role="${CLAUDE_SUBAGENT_ROLE:-subagent}"
  task="${CLAUDE_SUBAGENT_TASK:-nieznane zadanie}"
  {
    echo "CLAUDE_SUBAGENT_START_TIME=$(date +%s)"
    echo "CLAUDE_SUBAGENT_ROLE='${role}'"
    echo "CLAUDE_SUBAGENT_TASK='${task}'"
  } > .claude/runtime/subagent_start.env
fi
