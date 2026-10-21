#!/usr/bin/env python3
"""Save a worker model reported by Claude Code, independently of routing."""

import re
import sys
from pathlib import Path

from jev_common import (
    HERE, TOOL_VERSION, JevError, atomic_write_json, session_key, utc_now,
)
from session import model_name, read_payload


def handle(payload, home=HERE):
    if not isinstance(payload, dict):
        return False
    if payload.get("hook_event_name") != "PostToolUse":
        return False
    if payload.get("tool_name") not in ("Agent", "Task"):
        return False
    session_id = payload.get("session_id")
    if not isinstance(session_id, str) or not session_id or len(session_id) > 512:
        return False
    response = payload.get("tool_response")
    if not isinstance(response, dict):
        return False
    # A requested model in tool_input is not evidence of the executed model.
    resolved = response.get("resolvedModel")
    actual_model = model_name(resolved) if isinstance(resolved, str) else None
    if actual_model is None:
        return False
    status = response.get("status")
    scope = {
        "completed": "start",
        "async_launched": "background_launch",
    }.get(status, "reported")
    tool_use_id = payload.get("tool_use_id")
    if not isinstance(tool_use_id, str) or not re.fullmatch(
        r"[A-Za-z0-9_.:-]{1,200}", tool_use_id
    ):
        tool_use_id = None
    key = session_key(session_id)
    record = {
        "schema_version": 2,
        "tool_version": TOOL_VERSION,
        "timestamp": utc_now(),
        "session_key": key,
        "actual_model": actual_model,
        "observation_scope": scope,
        "tool_name": payload["tool_name"],
        "tool_use_id": tool_use_id,
        "association": "recent_worker_only_not_matched_to_a_route",
    }
    try:
        atomic_write_json(
            Path(home) / ".runtime" / "observations" / (key + ".json"), record
        )
    except (JevError, OSError, ValueError, TypeError):
        return False
    return True


def main():
    handle(read_payload(sys.stdin))
    return 0


if __name__ == "__main__":
    sys.exit(main())
