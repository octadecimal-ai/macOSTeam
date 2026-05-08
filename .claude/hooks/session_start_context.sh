#!/usr/bin/env bash
# SessionStart — wstrzyknięcie kontekstu wiedzy z MCP (fallback: knowledge_cli.py)
set -euo pipefail

PYTHON="/Users/experimental-lab/workspace/mcp/.venv/bin/python3"
CLI="/Users/experimental-lab/workspace/mcp/knowledge_cli.py"
MCP_SERVER="/Users/experimental-lab/workspace/mcp/server.py"

mkdir -p .claude/runtime
echo "[$(date -Iseconds)] SessionStart: wstrzyknięcie kontekstu wiedzy" >> .claude/runtime/knowledge.log

# Próbuj przez MCP JSON-RPC (server.py), fallback na CLI
if [[ -x "$PYTHON" && -f "$MCP_SERVER" ]]; then
  "$PYTHON" - << PY 2>/dev/null || true
import subprocess, json, sys

srv = subprocess.Popen(
    ["$PYTHON", "$MCP_SERVER"],
    stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL
)

def rpc(msg):
    body = json.dumps(msg)
    srv.stdin.write(f"Content-Length: {len(body)}\r\n\r\n{body}".encode())
    srv.stdin.flush()
    raw = b""
    while b"\r\n\r\n" not in raw:
        raw += srv.stdout.read(1)
    length = int([l for l in raw.decode().splitlines() if "Content-Length" in l][0].split(":")[1])
    return json.loads(srv.stdout.read(length))

rpc({"jsonrpc":"2.0","id":1,"method":"initialize","params":{
    "protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"hook","version":"1"}}})
notif = json.dumps({"jsonrpc":"2.0","method":"notifications/initialized","params":{}})
srv.stdin.write(f"Content-Length: {len(notif)}\r\n\r\n{notif}".encode())
srv.stdin.flush()

r = rpc({"jsonrpc":"2.0","id":2,"method":"tools/call","params":{
    "name":"get_knowledge_context",
    "arguments":{"scope":"team","min_confidence":0.65,"limit":8}}})

data = json.loads(r["result"]["content"][0]["text"])
if not data:
    print("Brak wpisów wiedzy.")
    srv.terminate(); sys.exit(0)

print(f"=== KONTEKST WIEDZY ZESPOŁU ({len(data)} wpisów) ===")
for item in data:
    print(f"\n[{item['scope'].upper()}] [{item['type']}] {item['title']}")
    print(f"  pewność={item['confidence']:.2f}  data={item['created_at'][:10]}")
    print(f"  {item['summary']}")
print("\n=== KONIEC KONTEKSTU ===")
srv.terminate()
PY
elif [[ -x "$PYTHON" && -f "$CLI" ]]; then
  "$PYTHON" "$CLI" context --scope team --min-confidence 0.65 --limit 8 2>/dev/null || true
fi
