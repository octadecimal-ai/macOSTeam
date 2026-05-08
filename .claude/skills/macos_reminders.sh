#!/usr/bin/env bash
# Skill: macOS Reminders — tworzenie i zamykanie przypomnień.
#
# Wywołanie:
#   macos_reminders.sh create "<tytuł>" [lista] [priorytet: 0-9] [termin: "YYYY-MM-DD HH:MM"]
#   macos_reminders.sh complete "<tytuł>" [lista]
#
# Priorytet: 0=brak, 1-4=niski, 5=średni, 6-9=wysoki
#
# Przykład:
#   macos_reminders.sh create "Zamknij PR #7" "macOSTeam" 5 "2026-05-09 10:00"
#   macos_reminders.sh complete "Zamknij PR #7" "macOSTeam"

set -euo pipefail

ACTION="${1:-}"
TITLE="${2:-}"
LIST="${3:-Przypomnienia}"
PRIORITY="${4:-0}"
DUE="${5:-}"

if [[ -z "$ACTION" || -z "$TITLE" ]]; then
  echo "Użycie: $0 <create|complete> <tytuł> [lista] [priorytet] [termin]" >&2
  exit 1
fi

safe_title="${TITLE//\"/\\\"}"
safe_list="${LIST//\"/\\\"}"

case "$ACTION" in
  create)
    if [[ -n "$DUE" ]]; then
      osascript << APPLESCRIPT
tell application "Reminders"
  if not (exists list "$safe_list") then
    make new list with properties {name:"$safe_list"}
  end if
  tell list "$safe_list"
    make new reminder with properties {¬
      name:"$safe_title", ¬
      priority:$PRIORITY, ¬
      due date:date "$DUE"}
  end tell
end tell
APPLESCRIPT
    else
      osascript << APPLESCRIPT
tell application "Reminders"
  if not (exists list "$safe_list") then
    make new list with properties {name:"$safe_list"}
  end if
  tell list "$safe_list"
    make new reminder with properties {¬
      name:"$safe_title", ¬
      priority:$PRIORITY}
  end tell
end tell
APPLESCRIPT
    fi
    echo "OK: przypomnienie '$TITLE' utworzone [lista: $LIST, priorytet: $PRIORITY]"
    ;;

  complete)
    osascript << APPLESCRIPT
tell application "Reminders"
  tell list "$safe_list"
    set targetReminder to first reminder whose name is "$safe_title"
    set completed of targetReminder to true
  end tell
end tell
APPLESCRIPT
    echo "OK: przypomnienie '$TITLE' zamknięte"
    ;;

  *)
    echo "Nieznana akcja: $ACTION. Użyj: create|complete" >&2
    exit 1
    ;;
esac
