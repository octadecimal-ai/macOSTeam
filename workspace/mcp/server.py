#!/usr/bin/env python3
"""MCP server — punkt zdawania wiedzy dla zespołu AI."""

import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path

from mcp.server.fastmcp import FastMCP

DB_PATH = Path(__file__).parent / "data" / "knowledge.db"
DB_PATH.parent.mkdir(exist_ok=True)

SCOPE_ORDER = ["agent", "team", "domain", "global"]
OBS_TYPES   = {"discovery", "repetition", "decision", "problem", "pattern"}
SEVERITIES  = {"minor", "major", "critical"}


def _db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def _init_db():
    with _db() as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS observations (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                type        TEXT    NOT NULL,
                title       TEXT    NOT NULL,
                summary     TEXT    NOT NULL,
                confidence  REAL    NOT NULL,
                scope       TEXT    NOT NULL,
                created_at  TEXT    NOT NULL,
                session_id  TEXT    DEFAULT '',
                draft       INTEGER DEFAULT 0
            )
        """)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS violations (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                severity    TEXT NOT NULL,
                description TEXT NOT NULL,
                created_at  TEXT NOT NULL,
                session_id  TEXT DEFAULT ''
            )
        """)


_init_db()
mcp = FastMCP("team-knowledge")


@mcp.tool()
def report_observation(
    type: str,
    title: str,
    summary: str,
    confidence: float,
    scope: str,
    session_id: str = "",
) -> str:
    """Zgłoś obserwację wiedzy (discovery/repetition/decision/problem/pattern).

    Obserwacje z confidence < 0.65 trafiają do szkicu i nie są widoczne w kontekście.
    """
    if type not in OBS_TYPES:
        return f"Błąd: type musi być jednym z {sorted(OBS_TYPES)}"
    if scope not in SCOPE_ORDER:
        return f"Błąd: scope musi być jednym z {SCOPE_ORDER}"
    if not 0.0 <= confidence <= 1.0:
        return "Błąd: confidence musi być między 0.0 a 1.0"

    draft = 1 if confidence < 0.65 else 0
    now = datetime.now(timezone.utc).isoformat()

    with _db() as conn:
        cur = conn.execute(
            "INSERT INTO observations (type, title, summary, confidence, scope, created_at, session_id, draft) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (type, title, summary, confidence, scope, now, session_id, draft),
        )
        obs_id = cur.lastrowid

    status = "SZKIC (confidence < 0.65)" if draft else "AKTYWNA"
    return f"OK: obserwacja #{obs_id} zapisana [{status}]"


@mcp.tool()
def get_knowledge_context(
    scope: str = "",
    min_confidence: float = 0.65,
    limit: int = 10,
) -> str:
    """Pobierz kontekst wiedzy dla bieżącej sesji.

    Opcjonalnie filtruj po scope (zwraca ten poziom i wyższe) i min_confidence.
    """
    query = "SELECT * FROM observations WHERE draft = 0 AND confidence >= ?"
    params: list = [min_confidence]

    if scope and scope in SCOPE_ORDER:
        idx = SCOPE_ORDER.index(scope)
        relevant = SCOPE_ORDER[idx:]
        placeholders = ",".join("?" * len(relevant))
        query += f" AND scope IN ({placeholders})"
        params.extend(relevant)

    query += " ORDER BY confidence DESC, created_at DESC LIMIT ?"
    params.append(limit)

    with _db() as conn:
        rows = conn.execute(query, params).fetchall()

    if not rows:
        return "Brak wpisów wiedzy spełniających kryteria."

    results = [
        {
            "id":         row["id"],
            "type":       row["type"],
            "title":      row["title"],
            "summary":    row["summary"],
            "confidence": row["confidence"],
            "scope":      row["scope"],
            "created_at": row["created_at"],
        }
        for row in rows
    ]
    return json.dumps(results, ensure_ascii=False, indent=2)


@mcp.tool()
def report_violation(
    severity: str,
    description: str,
    session_id: str = "",
) -> str:
    """Zaraportuj naruszenie watchdog (minor/major/critical)."""
    if severity not in SEVERITIES:
        return f"Błąd: severity musi być jednym z {sorted(SEVERITIES)}"

    now = datetime.now(timezone.utc).isoformat()

    with _db() as conn:
        cur = conn.execute(
            "INSERT INTO violations (severity, description, created_at, session_id) VALUES (?, ?, ?, ?)",
            (severity, description, now, session_id),
        )
        viol_id = cur.lastrowid

    return f"OK: naruszenie #{viol_id} zalogowane [severity={severity}]"


@mcp.tool()
def promote_knowledge(observation_id: int, new_scope: str) -> str:
    """Awansuj obserwację o jeden poziom scope (agent→team→domain→global)."""
    if new_scope not in SCOPE_ORDER:
        return f"Błąd: scope musi być jednym z {SCOPE_ORDER}"

    with _db() as conn:
        row = conn.execute("SELECT * FROM observations WHERE id = ?", (observation_id,)).fetchone()
        if not row:
            return f"Błąd: obserwacja #{observation_id} nie istnieje"

        curr_idx = SCOPE_ORDER.index(row["scope"])
        new_idx  = SCOPE_ORDER.index(new_scope)

        if new_idx <= curr_idx:
            return f"Błąd: można tylko awansować w górę. Obecny: {row['scope']}, żądany: {new_scope}"
        if new_idx > curr_idx + 1:
            next_scope = SCOPE_ORDER[curr_idx + 1]
            return f"Błąd: awansuj o jeden poziom na raz. Następny: {next_scope}"

        conn.execute("UPDATE observations SET scope = ? WHERE id = ?", (new_scope, observation_id))

    return f"OK: obserwacja #{observation_id} awansowana '{row['scope']}' → '{new_scope}'"


if __name__ == "__main__":
    mcp.run()
