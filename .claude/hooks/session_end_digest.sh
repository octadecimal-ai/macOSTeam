#!/usr/bin/env bash
set -euo pipefail

PYTHON="/Users/experimental-lab/workspace/mcp/.venv/bin/python3"
CLI="/Users/experimental-lab/workspace/mcp/knowledge_cli.py"

mkdir -p .claude/runtime
echo "[$(date -Iseconds)] SessionEnd: digest i kolejka promocji" >> .claude/runtime/knowledge.log

cat << 'DIGEST'
=== KONIEC SESJI: DIGEST WIEDZY ===
Zapisz obserwacje wysokiej wartości z tej sesji:
  .claude/hooks/knowledge_report.sh <type> <confidence> <scope> "<title>" "<summary>"

Sprawdź aktualną bazę wiedzy:
  /Users/experimental-lab/workspace/mcp/.venv/bin/python3 \
    /Users/experimental-lab/workspace/mcp/knowledge_cli.py context

Awansuj zwalidowane obserwacje:
  /Users/experimental-lab/workspace/mcp/.venv/bin/python3 \
    /Users/experimental-lab/workspace/mcp/knowledge_cli.py promote <id> <new_scope>
=== KONIEC DIGESTU ===
DIGEST

if [[ -x "$PYTHON" && -f "$CLI" ]]; then
  echo ""
  echo "--- Stan bazy na koniec sesji ---"
  "$PYTHON" "$CLI" context --min-confidence 0.0 --limit 5 2>/dev/null || true
fi
