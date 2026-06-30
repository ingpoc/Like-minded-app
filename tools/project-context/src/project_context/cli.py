from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

from project_context.bootstrap import session_start
from project_context.db import connect, ensure_layout, fetch_all_dicts, read_json
from project_context.decisions import find_matching_decisions, record_decision
from project_context.retrieval import (
    explain_decision,
    get_active_categories,
    get_active_decisions,
    get_decision_history,
    get_decision_trace,
    get_related_decision_context,
    query_active_decisions,
)

SEARCH_TOKEN_RE = re.compile(r"[A-Za-z0-9_]+")


def _print(payload: object) -> None:
    print(json.dumps(payload, indent=2, sort_keys=True))


def _fts_match_query(value: str) -> str:
    tokens = SEARCH_TOKEN_RE.findall(value)
    return " OR ".join(tokens) if tokens else value


def cmd_init(args: argparse.Namespace) -> None:
    paths = ensure_layout(Path(args.root).resolve())
    _print({"status": "ok", "graph_dir": str(paths.graph_dir), "db_path": str(paths.db_path)})


def cmd_doctor(args: argparse.Namespace) -> None:
    root = Path(args.root).resolve()
    paths = ensure_layout(root)
    conn = connect(root)
    tables = {
        row[0]
        for row in conn.execute("SELECT name FROM sqlite_master WHERE type IN ('table', 'virtual table')")
    }
    required = {"decision_versions", "active_decisions", "decision_traces", "decision_trace_links", "decision_search"}
    _print(
        {
            "status": "ok" if required <= tables else "missing_tables",
            "db_path": str(paths.db_path),
            "missing_tables": sorted(required - tables),
            "active_decision_count": len(get_active_decisions(root)),
        }
    )


def cmd_record_decision(args: argparse.Namespace) -> None:
    root = Path(args.root).resolve()
    payload = read_json(Path(args.path))
    matches = find_matching_decisions(
        root,
        category=payload.get("category", "general"),
        scope_key=payload.get("scope_key") or payload.get("scope") or "repo",
        owner_surface=payload.get("owner_surface") or "unknown",
    )
    if matches and payload.get("decision_key") not in {match["decision_key"] for match in matches} and not args.allow_same_category:
        _print(
            {
                "status": "blocked",
                "reason": "matching active decision exists for category/scope/owner; supersede it or pass --allow-same-category",
                "matches": matches,
            }
        )
        raise SystemExit(2)
    _print(record_decision(root, payload))


def cmd_active(args: argparse.Namespace) -> None:
    _print(get_active_decisions(Path(args.root).resolve()))


def cmd_categories(args: argparse.Namespace) -> None:
    _print(get_active_categories(Path(args.root).resolve()))


def cmd_query(args: argparse.Namespace) -> None:
    _print(
        query_active_decisions(
            Path(args.root).resolve(),
            args.task,
            categories=args.category,
            limit=args.limit,
        )
    )


def cmd_audit_active(args: argparse.Namespace) -> None:
    root = Path(args.root).resolve()
    conn = connect(root)
    orphaned = fetch_all_dicts(
        conn,
        """
        SELECT ad.decision_key
        FROM active_decisions ad
        LEFT JOIN decision_versions dv ON dv.id = ad.decision_version_id
        WHERE dv.id IS NULL OR dv.state != 'active'
        """,
    )
    _print({"status": "audited", "orphaned_active_decisions": orphaned, "removed_count": 0})


def cmd_history(args: argparse.Namespace) -> None:
    _print(get_decision_history(Path(args.root).resolve(), args.decision_key))


def cmd_explain(args: argparse.Namespace) -> None:
    _print(explain_decision(Path(args.root).resolve(), args.decision_key))


def cmd_trace(args: argparse.Namespace) -> None:
    _print(get_decision_trace(Path(args.root).resolve(), args.decision_key))


def cmd_related(args: argparse.Namespace) -> None:
    _print(get_related_decision_context(Path(args.root).resolve(), args.decision_key))


def cmd_session_start(args: argparse.Namespace) -> None:
    _print(session_start(Path(args.root).resolve()))


def cmd_search(args: argparse.Namespace) -> None:
    conn = connect(Path(args.root).resolve())
    match_query = _fts_match_query(args.query)
    rows = fetch_all_dicts(
        conn,
        """
        SELECT dv.id AS decision_version_id, dv.decision_key, dv.title, dv.summary
        FROM decision_versions dv
        JOIN (
            SELECT rowid, rank
            FROM decision_search
            WHERE decision_search MATCH ?
            ORDER BY rank
            LIMIT 10
        ) matched ON matched.rowid = dv.id
        WHERE dv.state = 'active'
        ORDER BY matched.rank
        """,
        (match_query,),
    )
    _print(rows)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="project-context")
    parser.add_argument("--root", default=".", help="Project root; defaults to cwd.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    init_parser = subparsers.add_parser("init")
    init_parser.set_defaults(func=cmd_init)

    doctor_parser = subparsers.add_parser("doctor")
    doctor_parser.set_defaults(func=cmd_doctor)

    record_parser = subparsers.add_parser("record-decision")
    record_parser.add_argument("path")
    record_parser.add_argument("--allow-same-category", action="store_true")
    record_parser.set_defaults(func=cmd_record_decision)

    active_parser = subparsers.add_parser("active")
    active_parser.set_defaults(func=cmd_active)

    categories_parser = subparsers.add_parser("categories")
    categories_parser.set_defaults(func=cmd_categories)

    query_parser = subparsers.add_parser("query")
    query_parser.add_argument("--task", required=True)
    query_parser.add_argument("--category", action="append", default=[])
    query_parser.add_argument("--limit", type=int, default=8)
    query_parser.set_defaults(func=cmd_query)

    audit_parser = subparsers.add_parser("audit-active")
    audit_parser.set_defaults(func=cmd_audit_active)

    history_parser = subparsers.add_parser("history")
    history_parser.add_argument("--decision-key", required=True)
    history_parser.set_defaults(func=cmd_history)

    explain_parser = subparsers.add_parser("explain")
    explain_parser.add_argument("--decision-key", required=True)
    explain_parser.set_defaults(func=cmd_explain)

    trace_parser = subparsers.add_parser("trace")
    trace_parser.add_argument("--decision-key", required=True)
    trace_parser.set_defaults(func=cmd_trace)

    related_parser = subparsers.add_parser("related")
    related_parser.add_argument("--decision-key", required=True)
    related_parser.set_defaults(func=cmd_related)

    session_start_parser = subparsers.add_parser("session-start")
    session_start_parser.set_defaults(func=cmd_session_start)

    search_parser = subparsers.add_parser("search")
    search_parser.add_argument("query")
    search_parser.set_defaults(func=cmd_search)

    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
