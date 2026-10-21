---
description: Preview the latest code change, or send it to Jev with --send for four problem-hunting questions
allowed-tools: Bash(python3 .claude/jev/check.py:*)
---

Run exactly this command and nothing else:

```
python3 .claude/jev/check.py $ARGUMENTS
```

With no arguments this is a **local preview only**. It calls no API, costs
nothing, and works while the Jev switch is off. It shows the diff that would be
sent, which files were excluded, and how many credentials were redacted.

Sending to Jev requires `--send`, and also requires the switch to be on
(`/jev on`). Everything after `--` is a path. So:

- `/jev-check` - preview uncommitted tracked changes against HEAD
- `/jev-check --include-untracked` - preview, including brand-new files
- `/jev-check --send` - actually ask Jev the four questions
- `/jev-check --send -- src/Thing.swift` - send one file only
- `/jev-check HEAD~1 HEAD` - preview one specific commit

There is no fallback to the last commit any more. With nothing uncommitted, a
bare `/jev-check` reports no eligible changes; name the commit explicitly.

Report the JSON the script prints, reading `status` first:

- `status: "preview"` - say this was a local preview and nothing was sent.
  Report the scope, the file list, `excluded_files` and `redactions`. There are
  no answers to report. If `send_blocked_by_sensitive_data` is true, say that
  sending would be refused until the flagged content is dealt with.
- `status: "completed"` - report the four answers as a table: the question, its
  `problem_probability`, and the `reading` the script already assigned. Higher
  is always worse, for every question. Report all four, including ones in the
  unsure band; the script sets no pass or fail threshold. Also report `usage`.
- `status: "skipped"` or `"error"` - report the `reason` and the `message`
  verbatim. Do not retry with different arguments.

A low score is not a passing test. The script runs no tests, and `completed`
only means four valid answers came back. Do not read the diff yourself and do
not fix anything unless the user asks.
