#!/usr/bin/env bash
set -euo pipefail

# Wiedza architektoniczna:
# - UserPromptSubmit może działać jako wczesna bramka zgodności procesu.
# - Ten skan wykrywa próby obchodzenia zasad jakości i bezpieczeństwa.

payload="$(cat || true)"
mkdir -p .claude/runtime

if [[ -z "$payload" ]]; then
  exit 0
fi

if echo "$payload" | rg -qi "zignoruj zasady|pom[iń] testy|bez test[oó]w|na skr[oó]ty|obejd[zź] review"; then
  .claude/hooks/watchdog_report.sh major "Wykryto próbę obejścia zasad w promptcie użytkownika."
fi

.claude/hooks/watchdog_snapshot.sh "UserPromptSubmit" "Skan zgodności promptu użytkownika."
