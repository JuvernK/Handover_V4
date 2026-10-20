---
description: Ask Jev four yes/no questions about the latest code change (weakened tests, swallowed errors, hidden side effects, stale comments)
allowed-tools: Bash(python3 .claude/jev/check.py:*)
---

Run exactly this command and nothing else:

```
python3 .claude/jev/check.py $ARGUMENTS
```

With no arguments it checks uncommitted work, falling back to the last commit.
Arguments are passed through to `git diff`, so `HEAD~1 HEAD` checks the previous
commit and `main...HEAD` checks the whole branch.

Then report Jev's four answers to the user as a table: the question, the
`problem_probability`, and the `reading` the script already assigned to it. All
four questions ask whether something is wrong, so a higher number is always
worse and no per-question direction needs explaining. Report every probability,
including the ones in the unsure band - the script sets no pass or fail
threshold. Also report the elapsed time and the token usage. Do not read the
diff yourself and do not fix anything unless the user asks.
