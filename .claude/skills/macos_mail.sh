#!/usr/bin/env bash
# Skill: macOS Mail — wysyłanie wiadomości email.
#
# Wywołanie:
#   macos_mail.sh send "<do>" "<temat>" "<treść>" [od]
#
# Przykład:
#   macos_mail.sh send "octadecimal@octadecimal.pl" "Raport sesji" "Zrealizowano: STORY-005"

set -euo pipefail

ACTION="${1:-}"
TO="${2:-}"
SUBJECT="${3:-}"
BODY="${4:-}"
FROM="${5:-}"

if [[ -z "$TO" || -z "$SUBJECT" || -z "$BODY" ]]; then
  echo "Użycie: $0 send <do> <temat> <treść> [od]" >&2
  exit 1
fi

safe_to="${TO//\"/\\\"}"
safe_subject="${SUBJECT//\"/\\\"}"
safe_body="${BODY//\"/\\\"}"

if [[ -n "$FROM" ]]; then
  safe_from="${FROM//\"/\\\"}"
  FROM_CLAUSE="set sender of newMessage to \"$safe_from\""
else
  FROM_CLAUSE=""
fi

osascript << APPLESCRIPT
tell application "Mail"
  set newMessage to make new outgoing message with properties {¬
    subject:"$safe_subject", ¬
    content:"$safe_body", ¬
    visible:false}
  $FROM_CLAUSE
  tell newMessage
    make new to recipient with properties {address:"$safe_to"}
  end tell
  send newMessage
end tell
APPLESCRIPT

echo "OK: email wysłany do '$TO' [temat: $SUBJECT]"
