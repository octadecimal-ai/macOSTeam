#!/usr/bin/env bash
set -euo pipefail

# Wiedza architektoniczna:
# - Eskalacja powinna być warstwowa: upomnienie -> notatka dla CEO -> twardy STOP.
# - Poziom krytyczny wymaga sygnału poza sesją (powiadomienie systemowe).

mkdir -p .claude/runtime
touch .claude/runtime/watchdog_violations.ndjson
touch .claude/runtime/watchdog.log

minor_count="$(rg -c '"severity":"minor"' .claude/runtime/watchdog_violations.ndjson || true)"
major_count="$(rg -c '"severity":"major"' .claude/runtime/watchdog_violations.ndjson || true)"
critical_count="$(rg -c '"severity":"critical"' .claude/runtime/watchdog_violations.ndjson || true)"

score=$(( minor_count + (major_count * 2) + (critical_count * 4) ))

level=0
if (( score >= 6 || critical_count >= 1 )); then
  level=3
elif (( score >= 3 || major_count >= 1 )); then
  level=2
elif (( score >= 1 )); then
  level=1
fi

previous_level=0
if [[ -f .claude/runtime/watchdog_state.env ]]; then
  # shellcheck disable=SC1091
  source .claude/runtime/watchdog_state.env || true
  previous_level="${ESCALATION_LEVEL:-0}"
fi

if (( level <= previous_level )); then
  exit 0
fi

echo "ESCALATION_LEVEL=$level" > .claude/runtime/watchdog_state.env
echo "[$(date -Iseconds)] Eskalacja watchdoga: poziom $level (score=$score)." >> .claude/runtime/watchdog.log

if (( level == 1 )); then
  echo "UPOMNIENIE: Wykryto drobne naruszenia regulaminu pracy." >> .claude/runtime/watchdog.log
fi

if (( level == 2 )); then
  cat > .claude/runtime/CEO_NOTATKA.md <<EOF
# Notatka do CEO

Data: $(date -Iseconds)
Powód: Watchdog wykrył istotne naruszenia regulaminu pracy zespołu AI.
Wynik oceny: score=$score, minor=$minor_count, major=$major_count, critical=$critical_count

Rekomendacja:
- Zweryfikować zgodność procesową zespołu.
- Potwierdzić, czy można kontynuować pracę bez ograniczeń.
EOF
fi

if (( level == 3 )); then
  touch .claude/runtime/team-stop.flag
  echo "STOP: Zespół został zatrzymany do czasu interwencji." >> .claude/runtime/watchdog.log

  if [[ "$(uname -s)" == "Darwin" ]]; then
    osascript -e 'display notification "Zespół AI został zatrzymany. Wymagana interwencja." with title "WATCHDOG: Krytyczna eskalacja"' || true
  fi
fi

.claude/hooks/watchdog_snapshot.sh "Stop" "Weryfikacja eskalacji watchdoga po zakończeniu odpowiedzi."
