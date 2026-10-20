#!/bin/bash
# Turn the Jev router on or off, or report its current state.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$HERE/state"
[ -f "$STATE_FILE" ] || echo off > "$STATE_FILE"
CURRENT="$(tr -d '[:space:]' < "$STATE_FILE")"

case "${1:-status}" in
  on)
    echo on > "$STATE_FILE"
    echo "Jev router: ON (was $CURRENT). Every prompt from now on is routed by Jev."
    ;;
  off)
    echo off > "$STATE_FILE"
    echo "Jev router: OFF (was $CURRENT). Prompts go straight to Claude again."
    ;;
  status|"")
    echo "Jev router: $(echo "$CURRENT" | tr "a-z" "A-Z")"
    ;;
  last)
    if [ -f "$HERE/last-decision.json" ]; then cat "$HERE/last-decision.json"; else echo "No routing decision recorded yet."; fi
    ;;
  *)
    echo "Usage: toggle.sh [on|off|status|last]" >&2
    exit 1
    ;;
esac
