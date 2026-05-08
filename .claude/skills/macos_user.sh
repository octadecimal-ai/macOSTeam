#!/usr/bin/env bash
# Skill: macOS User — zarządzanie headless kontami użytkowników systemu.
#
# Wywołanie:
#   macos_user.sh create <username> [fullname] [shell]
#   macos_user.sh delete <username>
#   macos_user.sh list
#   macos_user.sh exists <username>
#
# Przykład:
#   macos_user.sh create bigbrother "Big Brother Team" /bin/zsh
#   macos_user.sh delete bigbrother
#   macos_user.sh list
#
# Uwaga: create i delete wymagają sudo.

set -euo pipefail

ACTION="${1:-}"
USERNAME="${2:-}"
FULLNAME="${3:-$USERNAME}"
SHELL="${4:-/bin/zsh}"

require_username() {
  if [[ -z "$USERNAME" ]]; then
    echo "Błąd: brak nazwy użytkownika" >&2
    exit 1
  fi
}

case "$ACTION" in
  create)
    require_username

    if dscl . -read "/Users/$USERNAME" &>/dev/null; then
      echo "OK: użytkownik '$USERNAME' już istnieje"
      exit 0
    fi

    # Znajdź wolne UID w zakresie 500-599 (serwisowe, nieinteraktywne)
    uid=500
    while dscl . -list /Users UniqueID | awk '{print $2}' | grep -q "^${uid}$"; do
      uid=$((uid + 1))
    done

    sudo dscl . -create "/Users/$USERNAME"
    sudo dscl . -create "/Users/$USERNAME" UserShell "$SHELL"
    sudo dscl . -create "/Users/$USERNAME" RealName "$FULLNAME"
    sudo dscl . -create "/Users/$USERNAME" UniqueID "$uid"
    sudo dscl . -create "/Users/$USERNAME" PrimaryGroupID 20
    sudo dscl . -create "/Users/$USERNAME" NFSHomeDirectory "/Users/$USERNAME"
    sudo dscl . -create "/Users/$USERNAME" IsHidden 1

    sudo createhomedir -c -u "$USERNAME" &>/dev/null

    # Wyklucz z ekranu logowania
    sudo defaults write /Library/Preferences/com.apple.loginwindow HiddenUsersList -array-add "$USERNAME" 2>/dev/null || true

    echo "OK: użytkownik '$USERNAME' (UID $uid) utworzony [katalog: /Users/$USERNAME]"
    ;;

  delete)
    require_username

    if ! dscl . -read "/Users/$USERNAME" &>/dev/null; then
      echo "OK: użytkownik '$USERNAME' nie istnieje"
      exit 0
    fi

    sudo dscl . -delete "/Users/$USERNAME"

    if [[ -d "/Users/$USERNAME" ]]; then
      sudo rm -rf "/Users/$USERNAME"
    fi

    echo "OK: użytkownik '$USERNAME' usunięty"
    ;;

  list)
    echo "=== Headless użytkownicy (UID 500-599) ==="
    dscl . -list /Users UniqueID | awk '$2 >= 500 && $2 <= 599 {print $1, "(UID "$2")"}' | sort
    ;;

  exists)
    require_username
    if dscl . -read "/Users/$USERNAME" &>/dev/null; then
      echo "tak"
      exit 0
    else
      echo "nie"
      exit 1
    fi
    ;;

  *)
    echo "Użycie: $0 <create|delete|list|exists> [username] [fullname] [shell]" >&2
    exit 1
    ;;
esac
