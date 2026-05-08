#!/usr/bin/env bash
set -euo pipefail

# Wiedza architektoniczna:
# - Obserwacje o naruszeniach powinny być jawne i walidowalne.
# - Eskalacja opiera się o jakość sygnału, nie ilość logów.

severity="${1:-}"
reason="${2:-brak opisu}"

if [[ -z "$severity" ]]; then
  echo "Użycie: $0 <minor|major|critical> \"powód\"" >&2
  exit 1
fi

case "$severity" in
  minor|major|critical) ;;
  *)
    echo "Nieznany poziom naruszenia: $severity" >&2
    exit 1
    ;;
esac

mkdir -p .claude/runtime
printf '{"ts":"%s","severity":"%s","reason":"%s"}\n' "$(date -Iseconds)" "$severity" "$reason" >> .claude/runtime/watchdog_violations.ndjson
echo "[$(date -Iseconds)] Zgłoszono naruszenie: $severity | $reason" >> .claude/runtime/watchdog.log

.claude/hooks/watchdog_snapshot.sh "WatchdogReport" "Ręczne zgłoszenie naruszenia: ${severity}."
