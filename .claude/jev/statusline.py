#!/usr/bin/env python3
"""Claude Code status line: folder, git branch, model, and the Jev router switch.

Receives the session payload as JSON on stdin and prints one line.
"""

import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
STATE_FILE = os.path.join(HERE, "state")

DIM = "\033[2m"
GREEN = "\033[32m"
RESET = "\033[0m"


def dim(text):
    return DIM + text + RESET


def read_payload():
    try:
        return json.load(sys.stdin)
    except (ValueError, OSError):
        return {}


def git_branch():
    try:
        result = subprocess.run(
            ["git", "-C", HERE, "rev-parse", "--abbrev-ref", "HEAD"],
            capture_output=True,
            text=True,
            timeout=2,
        )
    except (OSError, subprocess.SubprocessError):
        return ""
    branch = result.stdout.strip()
    return branch if result.returncode == 0 and branch != "HEAD" else ""


def jev_segment():
    try:
        with open(STATE_FILE) as fh:
            is_on = fh.read().strip() == "on"
    except OSError:
        is_on = False
    return GREEN + "Jev: ON" + RESET if is_on else dim("Jev: off")


def main():
    payload = read_payload()
    current_dir = (payload.get("workspace") or {}).get("current_dir") or os.getcwd()
    model = (payload.get("model") or {}).get("display_name") or "?"

    segments = [dim(os.path.basename(current_dir.rstrip("/")) or "/")]
    branch = git_branch()
    if branch:
        segments.append(dim(branch))
    segments.append(dim(model))
    segments.append(jev_segment())

    sys.stdout.write(dim(" | ").join(segments))


if __name__ == "__main__":
    main()
