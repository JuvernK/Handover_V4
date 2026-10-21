#!/bin/bash
# Project-wide switch, shared with the existing mod and both Jev tools.
set -euo pipefail

JEV_SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
if [ "$#" -eq 0 ]; then
    set -- status
fi
if [ "$#" -ne 1 ]; then
    echo "Usage: toggle.sh [on|off|status|last]" >&2
    exit 1
fi

exec python3 - "$JEV_SCRIPT_DIR" "$1" <<'PY'
import json
import sys
from pathlib import Path

home = Path(sys.argv[1])
sys.path.insert(0, str(home))
from jev_common import JevError, atomic_write_text, is_enabled, read_decision

command = sys.argv[2]
try:
    if command in ("on", "off"):
        previous = "ON" if is_enabled(home) else "OFF"
        atomic_write_text(home / "state", command + "\n")
        print("Jev project switch: %s (was %s). Applies to router and checker." %
              (command.upper(), previous))
    elif command == "status":
        print("Jev project switch: %s. Applies to router and checker." %
              ("ON" if is_enabled(home) else "OFF"))
    elif command == "last":
        decision = read_decision(home)
        if decision.get("status") not in ("routed", "skipped", "error"):
            print("No current routing metadata. Legacy prompt logs are not displayed.")
        else:
            fields = (
                "schema_version", "tool_version", "version", "timestamp", "time",
                "session", "session_key", "session_hash", "status", "reason", "action",
                "recommended_model", "selected_model", "main_tier", "main_model_source",
                "skill", "answers", "jev_model", "usage", "input_chars", "redactions",
            )
            print(json.dumps({key: decision[key] for key in fields if key in decision},
                             indent=2, ensure_ascii=True, allow_nan=False))
    else:
        print("Usage: toggle.sh [on|off|status|last]", file=sys.stderr)
        sys.exit(1)
except (JevError, OSError, ValueError, TypeError):
    print("Jev switch could not read or update its local metadata.", file=sys.stderr)
    sys.exit(1)
PY
