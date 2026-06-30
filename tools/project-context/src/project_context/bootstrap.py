from __future__ import annotations

from pathlib import Path

from project_context.retrieval import get_active_categories, get_active_decisions


def session_start(root: Path) -> dict:
    return {
        "status": "ready",
        "active_decision_count": len(get_active_decisions(root)),
        "categories": get_active_categories(root),
    }
