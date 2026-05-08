#!/usr/bin/env bash
set -euo pipefail

# Wiedza architektoniczna:
# - ConfigChange pozwala wykryć modyfikacje ustawień i natychmiast je audytować.
# - Snapshot po zmianie konfiguracji tworzy punkt odtworzeniowy stanu całego katalogu.

mkdir -p .claude/runtime
echo "[$(date -Iseconds)] ConfigChange: wykryto zmianę konfiguracji Claude Code." >> .claude/runtime/watchdog.log

.claude/hooks/watchdog_snapshot.sh "ConfigChange" "Zmiana ustawień Claude Code i utworzenie punktu odtworzeniowego."
