---
description: Turn Jev on or off for this project, router and checker both (on | off | status | last)
allowed-tools: Bash(.claude/jev/toggle.sh:*)
# Only the user flips the switch: turning it on sends every prompt to Jev.
disable-model-invocation: true
---

Run exactly this command and nothing else:

```
.claude/jev/toggle.sh $ARGUMENTS
```

Report its output to the user verbatim as your whole reply. Do not add commentary,
do not read any other file, and do not take any other action.
