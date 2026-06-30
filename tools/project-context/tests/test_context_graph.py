from __future__ import annotations

import argparse
import json
from pathlib import Path

import pytest

from project_context.cli import cmd_record_decision, cmd_search
from project_context.db import connect, ensure_layout
from project_context.decisions import record_decision
from project_context.retrieval import (
    get_active_categories,
    get_active_decisions,
    get_decision_history,
    get_decision_trace,
    get_related_decision_context,
    query_active_decisions,
)


def decision_payload(**overrides):
    payload = {
        "decision_key": "validation.local-simulator-proof-owner",
        "decision_type": "precedent",
        "category": "validation.native",
        "scope_key": "Like-minded-app",
        "owner_surface": "goal.json",
        "title": "Use the existing local simulator proof",
        "summary": "Use npm run verify:simulator-local for local simulator proof.",
        "rationale": "The script already builds, launches, and captures auth gate plus signed-in tab evidence.",
        "task": "Validate local simulator proof",
        "situation": "Local proof was being repeated across sessions.",
        "inputs_considered": ["goal.json", "script/verify_simulator_local.sh"],
        "evidence": ["goal.json.validation_inventory.local_simulator"],
        "confidence": 1.0,
    }
    payload.update(overrides)
    return payload


def test_record_decision_creates_active_trace_and_category(tmp_path: Path) -> None:
    ensure_layout(tmp_path)
    result = record_decision(tmp_path, decision_payload())

    assert result["status"] == "recorded"
    active = get_active_decisions(tmp_path)
    assert len(active) == 1
    assert active[0]["decision_key"] == "validation.local-simulator-proof-owner"
    assert active[0]["owner_surface"] == "goal.json"
    assert get_active_categories(tmp_path) == [{"active_decision_count": 1, "category": "validation.native"}]

    trace = get_decision_trace(tmp_path, "validation.local-simulator-proof-owner")
    assert trace["evidence_refs"] == ["goal.json.validation_inventory.local_simulator"]
    assert trace["inputs_considered"] == ["goal.json", "script/verify_simulator_local.sh"]


def test_record_decision_supersedes_same_key(tmp_path: Path) -> None:
    ensure_layout(tmp_path)
    record_decision(tmp_path, decision_payload(summary="Use the first script."))
    record_decision(tmp_path, decision_payload(summary="Use npm run verify:simulator-local only when inputs change."))

    active = get_active_decisions(tmp_path)
    assert len(active) == 1
    assert active[0]["summary"] == "Use npm run verify:simulator-local only when inputs change."
    history = get_decision_history(tmp_path, "validation.local-simulator-proof-owner")
    assert [item["state"] for item in history] == ["superseded", "active"]

    related = get_related_decision_context(tmp_path, "validation.local-simulator-proof-owner")
    assert len(related["supersedes_edges"]) == 1


def test_query_and_search_find_active_decisions(tmp_path: Path, capsys) -> None:
    ensure_layout(tmp_path)
    record_decision(tmp_path, decision_payload())

    query = query_active_decisions(tmp_path, "native simulator validation proof")
    assert query["decision_count"] == 1
    assert query["decisions"][0]["decision_key"] == "validation.local-simulator-proof-owner"

    cmd_search(argparse.Namespace(root=str(tmp_path), query="simulator proof"))
    payload = json.loads(capsys.readouterr().out)
    assert payload[0]["decision_key"] == "validation.local-simulator-proof-owner"


def test_record_decision_blocks_duplicate_owner_category_scope(tmp_path: Path, capsys) -> None:
    ensure_layout(tmp_path)
    record_decision(tmp_path, decision_payload())
    duplicate_path = tmp_path / "duplicate.json"
    duplicate_path.write_text(
        json.dumps(
            decision_payload(
                decision_key="validation.another-proof",
                title="Another proof owner",
                summary="A duplicate owner/category/scope decision.",
            )
        ),
        encoding="utf-8",
    )

    with pytest.raises(SystemExit):
        cmd_record_decision(argparse.Namespace(root=str(tmp_path), path=str(duplicate_path), allow_same_category=False))
    payload = json.loads(capsys.readouterr().out)
    assert payload["status"] == "blocked"
    assert payload["matches"][0]["decision_key"] == "validation.local-simulator-proof-owner"


def test_schema_contains_no_raw_session_or_mining_tables(tmp_path: Path) -> None:
    ensure_layout(tmp_path)
    conn = connect(tmp_path)
    tables = {
        row[0]
        for row in conn.execute("SELECT name FROM sqlite_master WHERE type IN ('table', 'virtual table')")
    }
    assert "sessions" not in tables
    assert "session_events" not in tables
    assert "candidate_decisions" not in tables
    assert "mining_runs" not in tables
    assert "decision_versions" in tables
