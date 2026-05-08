#!/usr/bin/env python3
"""CLI do bazy wiedzy zespołu AI. Używane przez hooki Claude Code."""

import argparse
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path

DB_PATH = Path(__file__).parent / "data" / "knowledge.db"
SCOPE_ORDER = ["agent", "team", "domain", "global"]
OBS_TYPES   = sorted(["discovery", "repetition", "decision", "problem", "pattern"])


def db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def cmd_report(args):
    if args.type not in OBS_TYPES:
        print(f"Błąd: type musi być jednym z {OBS_TYPES}", file=sys.stderr)
        return 1
    if args.scope not in SCOPE_ORDER:
        print(f"Błąd: scope musi być jednym z {SCOPE_ORDER}", file=sys.stderr)
        return 1

    confidence = float(args.confidence)
    if not 0.0 <= confidence <= 1.0:
        print("Błąd: confidence musi być między 0.0 a 1.0", file=sys.stderr)
        return 1

    draft = 1 if confidence < 0.65 else 0
    now = datetime.now(timezone.utc).isoformat()

    with db() as conn:
        cur = conn.execute(
            "INSERT INTO observations (type, title, summary, confidence, scope, created_at, session_id, draft) "
            "VALUES (?,?,?,?,?,?,?,?)",
            (args.type, args.title, args.summary, confidence, args.scope, now, args.session, draft),
        )
        obs_id = cur.lastrowid

    status = "SZKIC" if draft else "AKTYWNA"
    print(f"OK: obserwacja #{obs_id} [{status}] [{args.scope}/{args.type}] {args.title}")
    return 0


def cmd_context(args):
    min_conf = float(args.min_confidence)
    limit    = int(args.limit)

    query  = "SELECT * FROM observations WHERE draft = 0 AND confidence >= ?"
    params: list = [min_conf]

    if args.scope and args.scope in SCOPE_ORDER:
        idx = SCOPE_ORDER.index(args.scope)
        buckets = SCOPE_ORDER[idx:]
        query += f" AND scope IN ({','.join('?'*len(buckets))})"
        params.extend(buckets)

    query += " ORDER BY confidence DESC, created_at DESC LIMIT ?"
    params.append(limit)

    with db() as conn:
        rows = conn.execute(query, params).fetchall()

    if not rows:
        print("Brak aktywnych wpisów wiedzy w bazie.")
        return 0

    print(f"=== KONTEKST WIEDZY ZESPOŁU ({len(rows)} wpisów) ===")
    for row in rows:
        print(f"\n[{row['scope'].upper()}] [{row['type']}] {row['title']}")
        print(f"  pewność={row['confidence']:.2f}  data={row['created_at'][:10]}")
        print(f"  {row['summary']}")
    print("\n=== KONIEC KONTEKSTU ===")
    return 0


def cmd_promote(args):
    obs_id    = int(args.id)
    new_scope = args.new_scope

    if new_scope not in SCOPE_ORDER:
        print(f"Błąd: scope musi być jednym z {SCOPE_ORDER}", file=sys.stderr)
        return 1

    with db() as conn:
        row = conn.execute("SELECT * FROM observations WHERE id = ?", (obs_id,)).fetchone()
        if not row:
            print(f"Błąd: obserwacja #{obs_id} nie istnieje", file=sys.stderr)
            return 1

        curr_idx = SCOPE_ORDER.index(row["scope"])
        new_idx  = SCOPE_ORDER.index(new_scope)

        if new_idx <= curr_idx:
            print(f"Błąd: tylko awans w górę. Obecny: {row['scope']}", file=sys.stderr)
            return 1
        if new_idx > curr_idx + 1:
            print(f"Błąd: jeden poziom na raz. Następny: {SCOPE_ORDER[curr_idx+1]}", file=sys.stderr)
            return 1

        conn.execute("UPDATE observations SET scope = ? WHERE id = ?", (new_scope, obs_id))

    print(f"OK: obserwacja #{obs_id} awansowana '{row['scope']}' → '{new_scope}'")
    return 0


def main():
    parser = argparse.ArgumentParser(description="Baza wiedzy zespołu AI")
    sub = parser.add_subparsers(dest="command", required=True)

    r = sub.add_parser("report", help="Zapisz obserwację")
    r.add_argument("type",       choices=OBS_TYPES)
    r.add_argument("confidence", type=float)
    r.add_argument("scope",      choices=SCOPE_ORDER)
    r.add_argument("title")
    r.add_argument("summary")
    r.add_argument("--session",  default="")

    c = sub.add_parser("context", help="Pobierz kontekst wiedzy")
    c.add_argument("--scope",           default="")
    c.add_argument("--min-confidence",  default="0.65", dest="min_confidence")
    c.add_argument("--limit",           default="10")

    p = sub.add_parser("promote", help="Awansuj obserwację o jeden poziom")
    p.add_argument("id")
    p.add_argument("new_scope", choices=SCOPE_ORDER)

    args = parser.parse_args()
    if args.command == "report":
        sys.exit(cmd_report(args))
    elif args.command == "context":
        sys.exit(cmd_context(args))
    elif args.command == "promote":
        sys.exit(cmd_promote(args))


if __name__ == "__main__":
    main()
