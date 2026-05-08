#!/usr/bin/env bash
# Skill: macOS Notes — tworzenie i dopisywanie notatek.
#
# Wywołanie:
#   macos_notes.sh create "<tytuł>" "<treść>" [folder]
#   macos_notes.sh append "<tytuł>" "<treść>"
#
# Przykład:
#   macos_notes.sh create "Sesja 2026-05-08" "Zrealizowano: serwer MCP" "macOSTeam"
#   macos_notes.sh append "Sesja 2026-05-08" "Dodano hooki powiadomień"

set -euo pipefail

ACTION="${1:-}"
TITLE="${2:-}"
BODY="${3:-}"
FOLDER="${4:-}"

if [[ -z "$ACTION" || -z "$TITLE" || -z "$BODY" ]]; then
  echo "Użycie: $0 <create|append> <tytuł> <treść> [folder]" >&2
  exit 1
fi

safe_title="${TITLE//\"/\\\"}"
safe_body="${BODY//\"/\\\"}"
safe_folder="${FOLDER//\"/\\\"}"

case "$ACTION" in
  create)
    if [[ -n "$FOLDER" ]]; then
      osascript << APPLESCRIPT
tell application "Notes"
  if not (exists folder "$safe_folder") then
    make new folder with properties {name:"$safe_folder"}
  end if
  tell folder "$safe_folder"
    make new note with properties {name:"$safe_title", body:"$safe_body"}
  end tell
end tell
APPLESCRIPT
    else
      osascript << APPLESCRIPT
tell application "Notes"
  make new note with properties {name:"$safe_title", body:"$safe_body"}
end tell
APPLESCRIPT
    fi
    echo "OK: notatka '$TITLE' utworzona"
    ;;

  append)
    osascript << APPLESCRIPT
tell application "Notes"
  set targetNote to first note whose name is "$safe_title"
  set body of targetNote to (body of targetNote) & "<br>$safe_body"
end tell
APPLESCRIPT
    echo "OK: dopisano do notatki '$TITLE'"
    ;;

  *)
    echo "Nieznana akcja: $ACTION. Użyj: create|append" >&2
    exit 1
    ;;
esac
