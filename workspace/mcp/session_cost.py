#!/usr/bin/env python3
"""Oblicza koszt bieżącej sesji automation assistant z pliku JSONL."""

import json
import sqlite3
import sys
from pathlib import Path

PROJECTS_DIR = Path.home() / ".llm" / "projects"
DB_PATH      = Path("/workspace/workspace/mcp/data/knowledge.db")


def find_current_session() -> Path | None:
    files = list(PROJECTS_DIR.glob("**/*.jsonl"))
    return max(files, key=lambda f: f.stat().st_mtime) if files else None


def get_usd_pln(conn: sqlite3.Connection) -> float:
    row = conn.execute(
        "SELECT value FROM market_data WHERE variable='USD_PLN' ORDER BY date DESC LIMIT 1"
    ).fetchone()
    return row["value"] if row else 4.0


def get_pricing(conn: sqlite3.Connection, model_id: str) -> sqlite3.Row | None:
    return conn.execute(
        "SELECT * FROM model_pricing WHERE model_id=? AND valid_to IS NULL ORDER BY valid_from DESC LIMIT 1",
        (model_id,)
    ).fetchone()


def parse_session(path: Path) -> dict[str, dict]:
    totals: dict[str, dict] = {}
    with open(path) as f:
        for line in f:
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue
            if entry.get("type") != "assistant":
                continue
            msg   = entry.get("message", {})
            model = msg.get("model", "")
            usage = msg.get("usage", {})
            if not model or not usage:
                continue
            if model not in totals:
                totals[model] = {"input": 0, "output": 0, "cache_write": 0, "cache_read": 0}
            totals[model]["input"]       += usage.get("input_tokens", 0)
            totals[model]["output"]      += usage.get("output_tokens", 0)
            totals[model]["cache_write"] += usage.get("cache_creation_input_tokens", 0)
            totals[model]["cache_read"]  += usage.get("cache_read_input_tokens", 0)
    return totals


def calculate(totals: dict, conn: sqlite3.Connection) -> tuple[float, float, float, list[str]]:
    usd_pln    = get_usd_pln(conn)
    total_usd  = 0.0
    breakdown  = []

    for model, tok in totals.items():
        p    = get_pricing(conn, model)
        name = p["model_name"] if p else model
        if p:
            cost = (
                tok["input"]       * p["input_usd_mtok"]  / 1_000_000 +
                tok["output"]      * p["output_usd_mtok"] / 1_000_000 +
                tok["cache_write"] * (p["cache_write_mtok"] or 0) / 1_000_000 +
                tok["cache_read"]  * (p["cache_read_mtok"]  or 0) / 1_000_000
            )
        else:
            cost = 0.0
        total_usd += cost
        all_tok = tok["input"] + tok["output"]
        breakdown.append(f"{name}: {all_tok:,} tok → ${cost:.4f}")

    return total_usd, total_usd * usd_pln, usd_pln, breakdown


def main() -> None:
    session = find_current_session()
    if not session:
        print("COST_USD=0\nCOST_PLN=0\nUSD_PLN=0\nBREAKDOWN=brak sesji")
        return

    with sqlite3.connect(DB_PATH) as conn:
        conn.row_factory = sqlite3.Row
        totals = parse_session(session)
        usd, pln, rate, breakdown = calculate(totals, conn)

    bd = " | ".join(breakdown) if breakdown else "brak danych"
    print(f"COST_USD={usd:.4f}")
    print(f"COST_PLN={pln:.4f}")
    print(f"USD_PLN={rate}")
    print(f"BREAKDOWN={bd}")


if __name__ == "__main__":
    main()
