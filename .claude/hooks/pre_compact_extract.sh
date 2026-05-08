#!/usr/bin/env bash
set -euo pipefail

mkdir -p .claude/runtime
echo "[$(date -Iseconds)] PreCompact: alert ekstrakcji wiedzy" >> .claude/runtime/knowledge.log

cat << 'ALERT'
=== ALERT: ZBLIŻA SIĘ KOMPAKCJA KONTEKSTU ===
Zapisz kluczowe obserwacje z bieżącej sesji PRZED utratą kontekstu:

  .claude/hooks/knowledge_report.sh <type> <confidence> <scope> "<title>" "<summary>"

  type:       discovery | repetition | decision | problem | pattern
  confidence: 0.0–1.0  (poniżej 0.65 → szkic, nie wstrzykiwany do przyszłych sesji)
  scope:      agent | team | domain | global

Przykład:
  .claude/hooks/knowledge_report.sh decision 0.85 team \
    "Watchdog snapshot wyłączony" "Snapshoty całego katalogu były zbyt ciężkie — zakomentowane"
=== KONIEC ALERTU ===
ALERT
