#!/usr/bin/env bash
# SubagentStop — powiadomienie po zakończeniu subagenta (jeśli pracował > 10 sek).
# Dane wejściowe ze zmiennych środowiskowych Claude Code:
#   CLAUDE_SUBAGENT_START_TIME  — epoch seconds (ustawiamy w PreToolUse dla Agent tool)
#   CLAUDE_SUBAGENT_ROLE        — np. "implementer", "reviewer"
#   CLAUDE_SUBAGENT_TASK        — krótki opis zadania

set -euo pipefail

PYTHON="/Users/experimental-lab/workspace/mcp/.venv/bin/python3"
NOTIFY="$(dirname "$0")/notify.sh"
RUNTIME=".claude/runtime"

mkdir -p "$RUNTIME"
echo "[$(date -Iseconds)] SubagentStop: ocena kandydatów do promocji wiedzy" >> "$RUNTIME/knowledge.log"

# ── Czas pracy ─────────────────────────────────────────────────────────────────
now_epoch="$(date +%s)"

# Odczytaj dane z pliku runtime (priorytet) lub env
if [[ -f "$RUNTIME/subagent_start.env" ]]; then
  set +e
  # shellcheck disable=SC1090
  source "$RUNTIME/subagent_start.env"
  set -e
fi

start_epoch="${CLAUDE_SUBAGENT_START_TIME:-}"
role="${CLAUDE_SUBAGENT_ROLE:-subagent}"
task="${CLAUDE_SUBAGENT_TASK:-nieznane zadanie}"

# Jeśli brak znacznika startowego — pomijamy
if [[ -z "$start_epoch" ]]; then
  exit 0
fi

duration=$(( now_epoch - start_epoch ))
rm -f "$RUNTIME/subagent_start.env"

# Pomijamy krótsze niż 10 sekund
(( duration < 10 )) && exit 0

# ── Formatuj czas ──────────────────────────────────────────────────────────────
if (( duration >= 60 )); then
  duration_str="$(( duration / 60 ))min $(( duration % 60 ))sek"
else
  duration_str="${duration}sek"
fi

# ── Liczba obserwacji MCP z tej sesji subagenta ────────────────────────────────
mcp_count="$("$PYTHON" -c "
import sqlite3
from datetime import datetime, timezone, timedelta
try:
    db = '/Users/experimental-lab/workspace/mcp/data/knowledge.db'
    conn = sqlite3.connect(db)
    cutoff = (datetime.now(timezone.utc) - timedelta(seconds=$duration + 30)).isoformat()
    n = conn.execute('SELECT COUNT(*) FROM observations WHERE created_at >= ?', (cutoff,)).fetchone()[0]
    print(n)
except Exception:
    print(0)
" 2>/dev/null)"

# ── Powiadomienie ──────────────────────────────────────────────────────────────
obs_str="brak"
(( mcp_count > 0 )) && obs_str="${mcp_count} obserwacji → MCP"

"$NOTIFY" info \
  "${role}: zadanie zakończone" \
  "Czas: ${duration_str} | Wiedza: ${obs_str}" \
  "${task}"
