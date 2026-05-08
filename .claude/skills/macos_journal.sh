#!/usr/bin/env bash
# Skill: macOS Journal — wpis do Dziennika (macOS Sonoma 14+).
#
# Journal nie ma pełnego AppleScript API — używamy Shortcuts jako mostu.
# Wymagane: shortcut "DodajWpisDziennik" z akcją "Utwórz wpis w Dzienniku".
#
# Wywołanie:
#   macos_journal.sh entry "<treść>"
#   macos_journal.sh setup   — instrukcja jak utworzyć shortcut
#
# Przykład:
#   macos_journal.sh entry "Sesja 2026-05-08: Zrealizowałem STORY-005, system skillów macOS działa"

set -euo pipefail

ACTION="${1:-entry}"
CONTENT="${2:-}"
SHORTCUT_NAME="DodajWpisDziennik"

case "$ACTION" in
  setup)
    cat << 'INSTRUCTIONS'
=== Konfiguracja skilla Journal ===

Utwórz Shortcut w aplikacji Skróty (Shortcuts.app):
1. Nowy skrót → dodaj akcję "Utwórz wpis w Dzienniku"
2. Ustaw treść na: "Tekst wejściowy ze skrótu" (Input)
3. Nazwij skrót: "DodajWpisDziennik"
4. Zapisz

Następnie przetestuj:
  .claude/skills/macos_journal.sh entry "Testowy wpis"
INSTRUCTIONS
    ;;

  entry)
    if [[ -z "$CONTENT" ]]; then
      echo "Błąd: brak treści wpisu" >&2
      exit 1
    fi

    # Próba przez Shortcuts
    if shortcuts run "$SHORTCUT_NAME" --input-string "$CONTENT" 2>/dev/null; then
      echo "OK: wpis dodany do Dziennika"
      exit 0
    fi

    # Fallback: URL scheme Journal
    encoded=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$CONTENT" 2>/dev/null || echo "$CONTENT")
    if open "journal://?text=${encoded}" 2>/dev/null; then
      echo "OK: otwarto Journal z treścią wpisu (zatwierdź ręcznie)"
      exit 0
    fi

    # Ostatni fallback: notatka w Notes z prefiksem
    TODAY=$(date '+%Y-%m-%d')
    osascript -e "tell application \"Notes\" to make new note with properties {name:\"Dziennik $TODAY\", body:\"$CONTENT\"}" 2>/dev/null && \
      echo "OK: fallback — wpis zapisany w Notes jako 'Dziennik $TODAY'" || \
      echo "Błąd: nie udało się zapisać wpisu. Uruchom: $0 setup" >&2
    ;;

  *)
    echo "Nieznana akcja: $ACTION. Użyj: entry|setup" >&2
    exit 1
    ;;
esac
