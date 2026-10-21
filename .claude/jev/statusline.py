#!/usr/bin/env python3
"""Local-only status: main model, routing status, and a recent worker report."""

import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

from jev_common import (
    HERE, JevError, is_enabled, load_config, read_decision, remember_main_model,
    safe_terminal_text, session_key,
)
from session import is_main_payload, model_name, read_payload


def git_branch(directory):
    try:
        result = subprocess.run(
            ["git", "-c", "core.fsmonitor=false", "-C", str(directory),
             "rev-parse", "--abbrev-ref", "HEAD"],
            capture_output=True, text=True, timeout=2, check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return ""
    branch = result.stdout.strip()
    return branch if result.returncode == 0 and branch != "HEAD" else ""


def recent_observation(home, session_id, max_age=86400):
    if not session_id:
        return {}
    path = Path(home) / ".runtime" / "observations" / (session_key(session_id) + ".json")
    try:
        if any(parent.is_symlink() for parent in [path] + list(path.parents)):
            return {}
        with path.open("r", encoding="utf-8") as stream:
            text = stream.read(16385)
        if len(text) > 16384:
            return {}
        record = json.loads(text)
        if not isinstance(record, dict):
            return {}
        if record.get("session_key") != session_key(session_id):
            return {}
        if model_name(record.get("actual_model")) is None:
            return {}
        timestamp = record.get("timestamp")
        if not isinstance(timestamp, str):
            return {}
        observed_at = datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
        if observed_at.tzinfo is None:
            return {}
        age = (datetime.now(timezone.utc) - observed_at).total_seconds()
        if age < -60 or age > max_age:
            return {}
        return record
    except (OSError, ValueError, TypeError, OverflowError):
        return {}


def route_segment(decision, global_view=False):
    prefix = "route(global)" if global_view else "route"
    if not isinstance(decision, dict) or decision.get("status") not in (
        "routed", "skipped", "error"
    ):
        return prefix + ": no recent decision"
    status = decision["status"]
    result = prefix + ": " + status
    if status == "routed" and decision.get("action") == "delegate":
        selected = decision.get("selected_model")
        if selected in ("opus", "sonnet", "haiku"):
            result = prefix + ": suggested " + selected
        else:
            result = prefix + ": defer"
    elif status == "routed":
        result = prefix + ": " + (
            "main" if decision.get("action") == "main" else "defer"
        )
    reason = decision.get("reason")
    if (status in ("skipped", "error") or decision.get("action") == "defer"
            or reason == "main_model_unknown"):
        if isinstance(reason, str) and reason:
            result += " (" + safe_terminal_text(reason)[:72] + ")"
    return safe_terminal_text(result)


def render(payload, home=HERE):
    home = Path(home)
    if not isinstance(payload, dict):
        payload = {}
    session_id = payload.get("session_id")
    if not isinstance(session_id, str) or not session_id or len(session_id) > 512:
        session_id = None
    raw_model = payload.get("model")
    model = model_name(raw_model)
    main_payload = is_main_payload(payload)
    if main_payload and session_id and model:
        try:
            remember_main_model(home, session_id, model, source="statusline")
        except (JevError, OSError, ValueError, TypeError):
            pass
    workspace = payload.get("workspace")
    workspace = workspace if isinstance(workspace, dict) else {}
    directory = workspace.get("current_dir")
    if not isinstance(directory, str) or not directory:
        directory = os.getcwd()
    display = raw_model.get("display_name") if isinstance(raw_model, dict) else model
    display = display if isinstance(display, str) and display else (model or "unknown")
    enabled = is_enabled(home)
    decision = read_decision(home, session_id=session_id)
    try:
        config = load_config(home)
        max_age = config["model_tracking_max_age_seconds"]
    except (JevError, OSError, ValueError, TypeError):
        max_age = 86400
    segments = [os.path.basename(directory.rstrip(os.sep)) or os.sep]
    branch = git_branch(directory)
    if branch:
        segments.append(branch)
    segments.extend([
        ("main: " if main_payload else "worker payload: ") + display,
        "Jev: ON" if enabled else "Jev: OFF",
        route_segment(decision, global_view=session_id is None),
    ])
    # This is an independent observation. It is not paired with the route above
    # and does not establish which model performed every step of a worker run.
    if main_payload:
        observation = recent_observation(home, session_id, max_age=max_age)
        if observation:
            label = {
                "start": "recent worker start: ",
                "background_launch": "recent worker launch: ",
                "reported": "recent worker reported: ",
            }.get(observation.get("observation_scope"), "recent worker reported: ")
            segments.append(label + observation["actual_model"])
    return " | ".join(safe_terminal_text(str(segment)) for segment in segments)


def main():
    sys.stdout.write(render(read_payload(sys.stdin)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
