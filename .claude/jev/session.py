#!/usr/bin/env python3
"""Record the main session model from documented lifecycle hook fields."""

import json
import sys
from pathlib import Path

from jev_common import HERE, JevError, remember_main_model


def read_payload(stream):
    try:
        text = stream.read(131073)
        if len(text) > 131072:
            return {}
        value = json.loads(text)
        return value if isinstance(value, dict) else {}
    except (OSError, ValueError, TypeError):
        return {}


def model_name(value):
    if isinstance(value, dict):
        for field in ("id", "model", "name", "display_name"):
            candidate = value.get(field)
            if isinstance(candidate, str) and candidate.strip():
                value = candidate
                break
        else:
            return None
    if not isinstance(value, str) or not value.strip() or len(value) > 512:
        return None
    if any(ord(char) < 32 or ord(char) == 127 for char in value):
        return None
    return value.strip()


def is_main_payload(payload):
    """A worker's status update must never replace the main session's model."""
    if not isinstance(payload, dict):
        return False
    # subagentStatusLine receives a batch of rows in ``tasks``. A row forwarded
    # by another status-line tool is identified by its documented task type.
    # In contrast, ``agent.name`` can describe a main session started with --agent.
    if "tasks" in payload or payload.get("type") == "local_agent":
        return False
    if payload.get("hook_event_name") in ("SubagentStart", "SubagentStop"):
        return False
    worker_fields = (
        "agent_id", "agentId", "subagent_id", "subagentId", "task_id", "taskId",
        "parent_session_id", "parentSessionId", "is_subagent", "isSubagent",
        "subagent_type", "task_status", "is_background", "isBackground",
    )
    return not any(payload.get(field) for field in worker_fields)


def handle(payload, home=HERE):
    if not isinstance(payload, dict) or not is_main_payload(payload):
        return False
    session_id = payload.get("session_id")
    if not isinstance(session_id, str) or not session_id or len(session_id) > 512:
        return False
    event = payload.get("hook_event_name")
    if event == "SessionStart":
        model = model_name(payload.get("model"))
    elif event == "PostModelSwitch":
        model = model_name(payload.get("to_model"))
    else:
        return False
    if model is None:
        return False
    try:
        # Unknown model families are deliberately recorded. They invalidate an
        # older known family instead of letting routing trust stale information.
        remember_main_model(Path(home), session_id, model, source=event)
    except (JevError, OSError, ValueError, TypeError):
        return False
    return True


def main():
    handle(read_payload(sys.stdin))
    return 0


if __name__ == "__main__":
    sys.exit(main())
