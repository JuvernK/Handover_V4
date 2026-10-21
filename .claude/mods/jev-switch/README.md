# jev-switch

A Claude Code mod for this repository. It draws the Jev switch as a pressable
control just above the prompt: `○ Jev off` or `● Jev on`, with a line of dim
text saying which way prompts are currently going. The dot carries the state as
shape as well as color, so the band still reads in a terminal with no color.

The mod holds no state of its own. It reads and writes `.claude/jev/state`, the
same file the `/jev` command and both Jev tools use, because the router runs as
its own process and that file is the only thing every side can see. Pressing the
button and typing `/jev on` therefore always agree.

The band is drawn only where `.claude/jev/state` exists, so the mod stays
invisible in other projects. Its path is built from the session's project root,
so it still works when Claude Code was started in a subdirectory of the project.

## Installing it

It is installed from this repository's own marketplace, so it loads in every
session rather than only the one that wrote it. To register it again on another
machine, or after clearing Claude Code's settings:

```
claude plugin marketplace add /path/to/Handover_V4/.claude/mods
claude plugin install jev-switch@handover-mods
```

Restart Claude Code afterwards. The marketplace entry records this folder's
path, so moving the repository means registering it again.

## Checking it

```
claude plugin validate .claude/mods/jev-switch
claude plugin test .claude/mods/jev-switch
```

The tests press the button and check that the state file flipped, that no band
is drawn where the file is absent, and that the band yields to a survey.
