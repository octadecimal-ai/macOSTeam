#!/usr/bin/env bash
set -euo pipefail

mkdir -p .claude/runtime
echo "[$(date -Iseconds)] PostToolBatch: punkt kontrolny semantyki batcha" >> .claude/runtime/knowledge.log
