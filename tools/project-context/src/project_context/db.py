from __future__ import annotations

import json
import sqlite3
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any, Iterable


SCHEMA_SQL = """
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS decision_versions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    decision_key TEXT NOT NULL,
    version_no INTEGER NOT NULL,
    state TEXT NOT NULL,
    decision_type TEXT NOT NULL,
    category TEXT NOT NULL,
    scope_key TEXT NOT NULL,
    owner_surface TEXT NOT NULL,
    title TEXT NOT NULL,
    summary TEXT NOT NULL,
    rationale_text TEXT NOT NULL,
    payload_json TEXT NOT NULL,
    effective_at TEXT NOT NULL,
    validated_at TEXT NOT NULL,
    UNIQUE(decision_key, version_no)
);

CREATE TABLE IF NOT EXISTS active_decisions (
    decision_key TEXT PRIMARY KEY,
    decision_version_id INTEGER NOT NULL REFERENCES decision_versions(id) ON DELETE CASCADE,
    activated_at TEXT NOT NULL,
    reason TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS supersedes_edges (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    from_decision_version_id INTEGER NOT NULL REFERENCES decision_versions(id) ON DELETE CASCADE,
    to_decision_version_id INTEGER NOT NULL REFERENCES decision_versions(id) ON DELETE CASCADE,
    relationship TEXT NOT NULL,
    confidence REAL NOT NULL,
    created_by TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS decision_traces (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    decision_version_id INTEGER NOT NULL REFERENCES decision_versions(id) ON DELETE CASCADE,
    decision_key TEXT NOT NULL,
    task_text TEXT NOT NULL,
    situation_text TEXT NOT NULL,
    inputs_considered_json TEXT NOT NULL,
    rule_or_policy TEXT NOT NULL,
    exception_or_override TEXT NOT NULL,
    precedent_used TEXT NOT NULL,
    approval_or_operator_signal TEXT NOT NULL,
    outcome_text TEXT NOT NULL,
    evidence_refs_json TEXT NOT NULL,
    confidence REAL NOT NULL,
    validation_status TEXT NOT NULL,
    created_at TEXT NOT NULL,
    UNIQUE(decision_version_id)
);

CREATE TABLE IF NOT EXISTS decision_trace_links (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    decision_trace_id INTEGER NOT NULL REFERENCES decision_traces(id) ON DELETE CASCADE,
    relationship TEXT NOT NULL,
    target_kind TEXT NOT NULL,
    target_key TEXT NOT NULL,
    target_label TEXT NOT NULL,
    evidence_ref TEXT NOT NULL,
    confidence REAL NOT NULL,
    created_by TEXT NOT NULL,
    UNIQUE(decision_trace_id, relationship, target_kind, target_key)
);

CREATE VIRTUAL TABLE IF NOT EXISTS decision_search USING fts5(
    decision_key,
    title,
    summary,
    rationale_text,
    content='',
    tokenize='unicode61'
);
"""


@dataclass(slots=True)
class Paths:
    root: Path
    graph_dir: Path
    db_path: Path
    schema_path: Path


def utc_now() -> str:
    return datetime.now(UTC).replace(microsecond=0).isoformat()


def build_paths(root: Path) -> Paths:
    graph_dir = root / ".context-graph"
    return Paths(
        root=root,
        graph_dir=graph_dir,
        db_path=graph_dir / "graph.db",
        schema_path=graph_dir / "schema.sql",
    )


def ensure_layout(root: Path) -> Paths:
    paths = build_paths(root)
    paths.graph_dir.mkdir(parents=True, exist_ok=True)
    if not paths.schema_path.exists() or paths.schema_path.read_text(encoding="utf-8") != SCHEMA_SQL:
        paths.schema_path.write_text(SCHEMA_SQL, encoding="utf-8")
    return paths


def connect(root: Path) -> sqlite3.Connection:
    paths = ensure_layout(root)
    conn = sqlite3.connect(paths.db_path, timeout=5.0)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    conn.execute("PRAGMA busy_timeout = 5000")
    try:
        conn.execute("PRAGMA journal_mode = WAL")
    except sqlite3.OperationalError as exc:
        if "locked" not in str(exc).lower():
            raise
    conn.executescript(SCHEMA_SQL)
    return conn


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def row_to_dict(row: sqlite3.Row) -> dict[str, Any]:
    return {key: row[key] for key in row.keys()}


def fetch_all_dicts(conn: sqlite3.Connection, query: str, params: Iterable[Any] = ()) -> list[dict[str, Any]]:
    return [row_to_dict(row) for row in conn.execute(query, params)]
