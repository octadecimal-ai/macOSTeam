#!/usr/bin/env bash
# System powiadomień macOS dla zespołu AI.
#
# Wywołanie:
#   notify.sh <level> "<title>" "<subtitle>" "<body>" [session_id]
#
# Poziomy: info | routing | escalation1 | escalation2 | escalation3

set -euo pipefail

LEVEL="${1:-info}"
TITLE="${2:-Zespół AI}"
SUBTITLE="${3:-}"
BODY="${4:-}"
SESSION_ID="${5:-}"

CONFIG="${HOME}/.claude/notify_config.json"
PYTHON="/Users/experimental-lab/workspace/mcp/.venv/bin/python3"
DB="/Users/experimental-lab/workspace/mcp/data/knowledge.db"

# ── Odczyt całego konfigu naraz (jeden proces Python) ──────────────────────────
eval "$("$PYTHON" - "$CONFIG" "$LEVEL" << 'PY'
import json, sys, os
cfg   = json.load(open(sys.argv[1]))
level = sys.argv[2]

def get(keys, default=""):
    val = cfg
    for k in keys.split("."):
        if not isinstance(val, dict): return default
        val = val.get(k, default)
    # normalizacja typów dla bash
    if isinstance(val, bool): return "true" if val else "false"
    if isinstance(val, list): return ",".join(str(x) for x in val)
    return str(val) if val is not None else default

print(f'GLOBAL_STATUS={get("global.status","active")}')
print(f'LOG_DB={get("global.log_to_db","true")}')
print(f'LEVEL_STATUS={get(f"levels.{level}.status","active")}')
print(f'SOUND={get(f"levels.{level}.sound","Glass")}')
print(f'BLOCKING={get(f"levels.{level}.blocking","false")}')
print(f'PREFIX={get(f"levels.{level}.subtitle_prefix","")}')
PY
)"

[[ "$GLOBAL_STATUS" != "active" ]] && exit 0
[[ "$LEVEL_STATUS"  != "active" ]] && exit 0

[[ -n "$PREFIX" ]] && SUBTITLE="${PREFIX} ${SUBTITLE}"

# ── Logowanie do bazy ──────────────────────────────────────────────────────────
log_notification() {
  [[ "$LOG_DB" != "true" ]] && return
  local response="${1:-}"
  "$PYTHON" - "$DB" "$LEVEL" "$TITLE" "$SUBTITLE" "$BODY" "$SESSION_ID" "$response" << 'PY'
import sys, sqlite3
from datetime import datetime, timezone
db, level, title, subtitle, body, session_id, response = sys.argv[1:]
with sqlite3.connect(db) as conn:
    conn.execute(
        "INSERT INTO notification_log (level,title,subtitle,body,sent_at,user_response,session_id) VALUES (?,?,?,?,?,?,?)",
        (level, title, subtitle, body, datetime.now(timezone.utc).isoformat(), response or None, session_id or None)
    )
PY
}

# ── Nieblokujące ───────────────────────────────────────────────────────────────
send_async() {
  if command -v terminal-notifier &>/dev/null; then
    terminal-notifier \
      -title "$TITLE" \
      -subtitle "$SUBTITLE" \
      -message "$BODY" \
      -sound "$SOUND" \
      -group "claude-${LEVEL}" \
      > /dev/null 2>&1 &
  else
    osascript -e "display notification \"$BODY\" with title \"$TITLE\" subtitle \"$SUBTITLE\" sound name \"$SOUND\"" &
  fi
  log_notification ""
}

# ── Blokujące z TAK/NIE ────────────────────────────────────────────────────────
send_blocking() {
  command -v terminal-notifier &>/dev/null && \
    terminal-notifier -title "$TITLE" -message "$BODY" -sound "$SOUND" -group "claude-${LEVEL}" > /dev/null 2>&1 || true

  local safe_body safe_title
  safe_body="${BODY//\"/\\\"}"
  safe_title="${TITLE//\"/\\\"}"

  RESPONSE=$(osascript << APPLESCRIPT
button returned of (display dialog "$safe_body" ¬
  buttons {"NIE", "TAK"} ¬
  default button 1 ¬
  with title "$safe_title" ¬
  with icon caution)
APPLESCRIPT
  )

  log_notification "$RESPONSE"
  [[ "$RESPONSE" == "TAK" ]]
}

# ── Escalation3: TAK → sudo → skrypt izolacji ─────────────────────────────────
send_escalation3() {
  send_blocking || { log_notification "NIE"; return 0; }

  local isolate_script
  isolate_script="$(dirname "$0")/escalation3_isolate.sh"
  local status="błąd"
  osascript -e "do shell script \"$isolate_script\" with administrator privileges" 2>/dev/null && status="sukces" || true

  local result_msg="Skrypt izolacji: $status. Raport: .claude/runtime/"
  osascript -e "display notification \"$result_msg\" with title \"Incydent — wynik\" subtitle \"Eskalacja 3 zakończona\" sound name \"Glass\"" &
  log_notification "TAK:$status"
}

# ── Dispatch ───────────────────────────────────────────────────────────────────
case "$LEVEL" in
  info|routing|escalation1) send_async     ;;
  escalation2)              send_blocking  ;;
  escalation3)              send_escalation3 ;;
  *)
    echo "Nieznany poziom: $LEVEL. Użyj: info|routing|escalation1|escalation2|escalation3" >&2
    exit 1
    ;;
esac
