#!/usr/bin/env bash
# Powiadomienie gdy Claude kończy odpowiedź i czeka na użytkownika.
# Trigger: Stop hook

set -euo pipefail

PYTHON="/Users/experimental-lab/workspace/mcp/.venv/bin/python3"
CONFIG="${HOME}/.claude/notify_config.json"
NOTIFY="$(dirname "$0")/notify.sh"

mkdir -p .claude/runtime

# ── Ostatnia akcja z knowledge.log ────────────────────────────────────────────
last_action="$(tail -n 1 .claude/runtime/knowledge.log 2>/dev/null \
  | sed 's/\[.*\] //' | cut -c1-80 || echo 'Gotowy na Twoją odpowiedź')"

# ── Koszt sesji ────────────────────────────────────────────────────────────────
cost_output="$("$PYTHON" /Users/experimental-lab/workspace/mcp/session_cost.py 2>/dev/null \
  || echo 'COST_USD=0
COST_PLN=0
USD_PLN=0
BREAKDOWN=błąd kalkulacji')"
COST_USD="$(echo "$cost_output" | grep '^COST_USD=' | cut -d= -f2)"
COST_PLN="$(echo "$cost_output" | grep '^COST_PLN=' | cut -d= -f2)"
BREAKDOWN="$(echo "$cost_output" | grep '^BREAKDOWN=' | cut -d= -f2-)"

cost_str="$("$PYTHON" -c "print(f'{float(\"$COST_PLN\"):.2f} PLN  ({float(\"$COST_USD\"):.4f} USD)')" 2>/dev/null || echo "${COST_PLN} PLN")"

# ── Powiadomienie "Claude czeka" ───────────────────────────────────────────────
"$NOTIFY" info \
  "Claude czeka na odpowiedź" \
  "Koszt sesji: $cost_str" \
  "$last_action"

# ── Alert kosztowy (jeśli przekroczono próg) ───────────────────────────────────
threshold="$("$PYTHON" - "$CONFIG" << 'PY'
import json, sys
try:
    cfg = json.load(open(sys.argv[1]))
    print(cfg.get("cost_alert", {}).get("threshold_pln", 5.0))
except Exception:
    print(5.0)
PY
)"

if "$PYTHON" -c "import sys; sys.exit(0 if float('$COST_PLN') > float('$threshold') else 1)" 2>/dev/null; then
  "$NOTIFY" escalation1 \
    "Alert kosztowy" \
    "Próg ${threshold} PLN przekroczony" \
    "Koszt sesji: ${cost_str} | ${BREAKDOWN}"
fi
