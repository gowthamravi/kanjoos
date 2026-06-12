"""Budget ledger and month-end state machine.

SQLite-backed. All amounts in INR. The "simulated date" override exists so
demos can jump to day 26 of the month without waiting three weeks.
"""

import os
import sqlite3
from calendar import monthrange
from datetime import date, datetime
from pathlib import Path

DB_PATH = Path(os.getenv("KANJOOS_DB", Path(__file__).resolve().parent.parent / "kanjoos.db"))

DEFAULT_BUDGET = float(os.getenv("MONTHLY_BUDGET_DEFAULT", "8000"))


def _conn() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    with _conn() as conn:
        conn.execute(
            "CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)"
        )
        conn.execute(
            """CREATE TABLE IF NOT EXISTS spends (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                amount REAL NOT NULL,
                description TEXT NOT NULL,
                source TEXT NOT NULL DEFAULT 'manual',
                spent_at TEXT NOT NULL
            )"""
        )


def _get_setting(key: str) -> str | None:
    with _conn() as conn:
        row = conn.execute("SELECT value FROM settings WHERE key = ?", (key,)).fetchone()
    return row["value"] if row else None


def _set_setting(key: str, value: str | None) -> None:
    with _conn() as conn:
        if value is None:
            conn.execute("DELETE FROM settings WHERE key = ?", (key,))
        else:
            conn.execute(
                "INSERT INTO settings (key, value) VALUES (?, ?) "
                "ON CONFLICT(key) DO UPDATE SET value = excluded.value",
                (key, value),
            )


def today() -> date:
    override = _get_setting("sim_date")
    if override:
        return date.fromisoformat(override)
    return date.today()


def set_sim_date(value: str | None) -> None:
    if value:
        date.fromisoformat(value)  # validate
    _set_setting("sim_date", value)


def get_monthly_budget() -> float:
    value = _get_setting("monthly_budget")
    return float(value) if value else DEFAULT_BUDGET


def set_monthly_budget(amount: float) -> None:
    _set_setting("monthly_budget", str(amount))


def log_spend(amount: float, description: str, source: str = "manual", spent_at: date | None = None) -> None:
    when = (spent_at or today()).isoformat()
    with _conn() as conn:
        conn.execute(
            "INSERT INTO spends (amount, description, source, spent_at) VALUES (?, ?, ?, ?)",
            (amount, description, source, when),
        )


def recent_spends(limit: int = 15) -> list[dict]:
    with _conn() as conn:
        rows = conn.execute(
            "SELECT amount, description, source, spent_at FROM spends ORDER BY id DESC LIMIT ?",
            (limit,),
        ).fetchall()
    return [dict(r) for r in rows]


def get_status() -> dict:
    """Compute the budget health snapshot that drives the agent's personality."""
    now = today()
    budget = get_monthly_budget()
    month_start = now.replace(day=1).isoformat()
    with _conn() as conn:
        row = conn.execute(
            "SELECT COALESCE(SUM(amount), 0) AS total FROM spends WHERE spent_at >= ?",
            (month_start,),
        ).fetchone()
    spent = float(row["total"])

    days_in_month = monthrange(now.year, now.month)[1]
    days_left = days_in_month - now.day + 1  # including today
    remaining = budget - spent
    daily_baseline = budget / days_in_month
    safe_daily = remaining / days_left if days_left > 0 else remaining

    if remaining <= 0:
        state = "red"
    else:
        ratio = safe_daily / daily_baseline
        state = "green" if ratio >= 0.85 else "yellow" if ratio >= 0.45 else "red"

    return {
        "date": now.isoformat(),
        "monthly_budget": round(budget, 2),
        "spent": round(spent, 2),
        "remaining": round(remaining, 2),
        "days_left": days_left,
        "daily_baseline": round(daily_baseline, 2),
        "safe_daily_spend": round(safe_daily, 2),
        "state": state,
        "sim_date_active": _get_setting("sim_date") is not None,
    }
