#!/usr/bin/env bash
# Wysyła push tylko gdy eskalacja >= 1 lub są naruszenia.
# Sygnatura zachowana dla kompatybilności: watchdog_snapshot.sh "<hook>" "<reason>"

set -euo pipefail

hook_name="${1:-unknown-hook}"
reason="${2:-}"

runtime_dir=".claude/runtime"
mkdir -p "$runtime_dir"
touch "${runtime_dir}/watchdog.log" "${runtime_dir}/knowledge.log" "${runtime_dir}/watchdog_violations.ndjson"

count_violations() {
  local sev="$1"
  awk -v pat="\"severity\":\"${sev}\"" 'index($0, pat)>0{c++} END{print c+0}' \
    "${runtime_dir}/watchdog_violations.ndjson" 2>/dev/null || echo 0
}

escalation_level=0
[[ -f "${runtime_dir}/watchdog_state.env" ]] && source "${runtime_dir}/watchdog_state.env" 2>/dev/null || true
escalation_level="${ESCALATION_LEVEL:-0}"

minor="$(count_violations minor)"
major="$(count_violations major)"
critical="$(count_violations critical)"

# Cicho przy braku naruszeń i braku eskalacji
(( escalation_level == 0 && minor == 0 && major == 0 && critical == 0 )) && exit 0

# Wybór poziomu
notify_level="escalation1"
(( escalation_level >= 3 || critical > 0 )) && notify_level="escalation3"
(( escalation_level == 2 || major > 0 ))    && notify_level="escalation2"

NOTIFY="$(dirname "$0")/notify.sh"
"$NOTIFY" "$notify_level" \
  "Watchdog — ${hook_name}" \
  "minor=${minor} major=${major} critical=${critical} | eskalacja=${escalation_level}" \
  "${reason:-Naruszenie procesowe wykryte przez watchdog.}"
