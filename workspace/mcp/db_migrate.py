#!/usr/bin/env python3
"""Migracja schematu bazy wiedzy — uruchom raz dla każdej wersji."""

import sqlite3
from datetime import datetime, timezone
from pathlib import Path

DB_PATH = Path(__file__).parent / "data" / "knowledge.db"


def migrate(conn: sqlite3.Connection) -> None:
    conn.executescript("""
    -- ── Metryki sesji ─────────────────────────────────────────────────────────
    CREATE TABLE IF NOT EXISTS session_metrics (
        id                    INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id            TEXT,
        project               TEXT,
        model                 TEXT,
        agent_role            TEXT,
        started_at            TEXT,
        ended_at              TEXT,
        duration_seconds      INTEGER,
        input_tokens          INTEGER DEFAULT 0,
        output_tokens         INTEGER DEFAULT 0,
        cache_creation_tokens INTEGER DEFAULT 0,
        cache_read_tokens     INTEGER DEFAULT 0,
        cost_usd              REAL,
        cost_pln              REAL,
        usd_pln_rate          REAL,
        task_name             TEXT,
        created_at            TEXT
    );

    -- ── Historia powiadomień ───────────────────────────────────────────────────
    CREATE TABLE IF NOT EXISTS notification_log (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        level         TEXT NOT NULL,
        title         TEXT,
        subtitle      TEXT,
        body          TEXT,
        sent_at       TEXT NOT NULL,
        user_response TEXT,
        session_id    TEXT
    );

    -- ── Cennik modeli ──────────────────────────────────────────────────────────
    CREATE TABLE IF NOT EXISTS model_pricing (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        model_id         TEXT NOT NULL,
        model_name       TEXT NOT NULL,
        input_usd_mtok   REAL NOT NULL,
        output_usd_mtok  REAL NOT NULL,
        cache_write_mtok REAL,
        cache_read_mtok  REAL,
        valid_from       TEXT NOT NULL,
        valid_to         TEXT,
        source           TEXT,
        created_at       TEXT NOT NULL
    );

    -- ── Dane rynkowe (kursy walut, inne zmienne) ───────────────────────────────
    CREATE TABLE IF NOT EXISTS market_data (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        variable   TEXT NOT NULL,
        value      REAL NOT NULL,
        date       TEXT NOT NULL,
        source     TEXT,
        note       TEXT,
        created_at TEXT NOT NULL
    );

    CREATE UNIQUE INDEX IF NOT EXISTS idx_market_data_var_date
        ON market_data (variable, date);
    """)


def seed_pricing(conn: sqlite3.Connection, today: str, now: str) -> None:
    """Cennik modeli LLM — stan na 2026-05-08. Źródło: llm-provider.com/pricing."""
    pricing = [
        # (model_id, model_name, input, output, cache_write, cache_read)
        ("llm-opus-4-7",           "LLM Opus 4.7",  15.00, 75.00, 18.75, 1.50),
        ("llm-sonnet-4-6",         "LLM Sonnet 4.6",  3.00, 15.00,  3.75, 0.30),
        ("llm-haiku-4-5-20251001", "LLM Haiku 4.5",   0.80,  4.00,  1.00, 0.08),
    ]
    for row in pricing:
        conn.execute(
            """INSERT OR IGNORE INTO model_pricing
               (model_id, model_name, input_usd_mtok, output_usd_mtok,
                cache_write_mtok, cache_read_mtok, valid_from, source, created_at)
               VALUES (?,?,?,?,?,?,?,?,?)""",
            (*row, today, "llm-provider.com/pricing", now),
        )


def seed_market(conn: sqlite3.Connection, today: str, now: str) -> None:
    """Dane rynkowe na dzień dzisiejszy."""
    rows = [
        # (variable, value, source, note)
        ("USD_PLN", 3.5947, "NBP",    "Tabela A nr 088/A/NBP/2026, 2026-05-08"),
        ("EUR_PLN", 4.2500, "manual", "Wartość orientacyjna — zastąp kursem NBP"),
    ]
    for variable, value, source, note in rows:
        conn.execute(
            """INSERT OR IGNORE INTO market_data
               (variable, value, date, source, note, created_at)
               VALUES (?,?,?,?,?,?)""",
            (variable, value, today, source, note, now),
        )


def main() -> None:
    now   = datetime.now(timezone.utc).isoformat()
    today = now[:10]

    with sqlite3.connect(DB_PATH) as conn:
        migrate(conn)
        seed_pricing(conn, today, now)
        seed_market(conn, today, now)

    print("Migracja zakończona. Tabele: session_metrics, notification_log, model_pricing, market_data")
    with sqlite3.connect(DB_PATH) as conn:
        conn.row_factory = sqlite3.Row
        for tbl in ("model_pricing", "market_data"):
            rows = conn.execute(f"SELECT * FROM {tbl}").fetchall()
            print(f"\n── {tbl} ({len(rows)} wierszy) ──")
            for r in rows:
                print(" ", dict(r))


if __name__ == "__main__":
    main()
