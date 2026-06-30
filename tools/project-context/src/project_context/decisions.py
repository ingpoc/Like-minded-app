from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from project_context.categories import normalize_category
from project_context.db import connect, fetch_all_dicts, utc_now


def _json_list(value: Any) -> str:
    if value is None:
        value = []
    if not isinstance(value, list):
        raise ValueError("expected a list")
    return json.dumps(value, sort_keys=True)


def _active_version(conn, decision_key: str):
    return conn.execute(
        """
        SELECT dv.*
        FROM active_decisions ad
        JOIN decision_versions dv ON dv.id = ad.decision_version_id
        WHERE ad.decision_key = ?
        """,
        (decision_key,),
    ).fetchone()


def find_matching_decisions(root: Path, *, category: str, scope_key: str, owner_surface: str) -> list[dict]:
    conn = connect(root)
    return fetch_all_dicts(
        conn,
        """
        SELECT dv.id, dv.decision_key, dv.version_no, dv.state, dv.category, dv.scope_key, dv.owner_surface, dv.title, dv.summary
        FROM active_decisions ad
        JOIN decision_versions dv ON dv.id = ad.decision_version_id
        WHERE dv.category = ? AND dv.scope_key = ? AND dv.owner_surface = ?
        ORDER BY dv.decision_key
        """,
        (normalize_category(category), scope_key, owner_surface),
    )


def record_decision(root: Path, payload: dict[str, Any]) -> dict:
    decision_key = payload["decision_key"]
    category = normalize_category(payload.get("category", "general"))
    scope_key = payload.get("scope_key") or payload.get("scope") or "repo"
    owner_surface = payload.get("owner_surface") or "unknown"
    now = utc_now()
    conn = connect(root)
    existing = _active_version(conn, decision_key)
    version_no = int(existing["version_no"]) + 1 if existing else 1
    supersedes = payload.get("supersedes")
    if supersedes is None and existing:
        supersedes = decision_key

    conn.execute("BEGIN IMMEDIATE")
    try:
        if existing:
            conn.execute("UPDATE decision_versions SET state = 'superseded' WHERE id = ?", (existing["id"],))
            conn.execute("DELETE FROM active_decisions WHERE decision_key = ?", (decision_key,))

        decision_version_id = conn.execute(
            """
            INSERT INTO decision_versions(
                decision_key, version_no, state, decision_type, category, scope_key, owner_surface,
                title, summary, rationale_text, payload_json, effective_at, validated_at
            ) VALUES (?, ?, 'active', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                decision_key,
                version_no,
                payload.get("decision_type", "precedent"),
                category,
                scope_key,
                owner_surface,
                payload.get("title") or decision_key,
                payload["summary"],
                payload.get("rationale") or payload.get("rationale_text") or "",
                json.dumps(payload, sort_keys=True),
                payload.get("effective_at") or now,
                now,
            ),
        ).lastrowid
        conn.execute(
            """
            INSERT INTO active_decisions(decision_key, decision_version_id, activated_at, reason)
            VALUES (?, ?, ?, ?)
            """,
            (decision_key, decision_version_id, now, payload.get("activation_reason", "accepted decision")),
        )
        trace_id = conn.execute(
            """
            INSERT INTO decision_traces(
                decision_version_id, decision_key, task_text, situation_text, inputs_considered_json,
                rule_or_policy, exception_or_override, precedent_used, approval_or_operator_signal,
                outcome_text, evidence_refs_json, confidence, validation_status, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                decision_version_id,
                decision_key,
                payload.get("task") or "",
                payload.get("situation") or "",
                _json_list(payload.get("inputs_considered")),
                payload.get("rule_or_policy") or "",
                payload.get("exception_or_override") or "",
                payload.get("precedent_used") or "",
                payload.get("approval_or_operator_signal") or "",
                payload.get("outcome") or payload["summary"],
                _json_list(payload.get("evidence")),
                float(payload.get("confidence", 1.0)),
                payload.get("validation_status") or "accepted",
                now,
            ),
        ).lastrowid
        for link in payload.get("links", []):
            conn.execute(
                """
                INSERT INTO decision_trace_links(
                    decision_trace_id, relationship, target_kind, target_key, target_label,
                    evidence_ref, confidence, created_by
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    trace_id,
                    link["relationship"],
                    link["target_kind"],
                    link["target_key"],
                    link.get("target_label") or link["target_key"],
                    link.get("evidence_ref") or "",
                    float(link.get("confidence", 1.0)),
                    link.get("created_by") or "record_decision",
                ),
            )
        if supersedes:
            target = existing if supersedes == decision_key else _active_version(conn, supersedes)
            if target:
                conn.execute(
                    """
                    INSERT INTO supersedes_edges(from_decision_version_id, to_decision_version_id, relationship, confidence, created_by)
                    VALUES (?, ?, 'supersedes', ?, 'record_decision')
                    """,
                    (decision_version_id, target["id"], float(payload.get("confidence", 1.0))),
                )
        conn.execute(
            """
            INSERT INTO decision_search(rowid, decision_key, title, summary, rationale_text)
            VALUES (?, ?, ?, ?, ?)
            """,
            (
                decision_version_id,
                decision_key,
                payload.get("title") or decision_key,
                payload["summary"],
                payload.get("rationale") or payload.get("rationale_text") or "",
            ),
        )
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    return {
        "status": "recorded",
        "decision_key": decision_key,
        "decision_version_id": decision_version_id,
        "version_no": version_no,
        "superseded": bool(existing),
    }
