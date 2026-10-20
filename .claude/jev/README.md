# Jev in this project

Two separate tools, both backed by TypeSafe's Jev model. They share nothing but
the API key.

| Tool | When it runs | What it does |
| --- | --- | --- |
| **Router** (`route.py`) | Automatically, on every prompt, while the switch is `on` | Picks the model tier and the skill for that prompt |
| **Check** (`check.py`) | Only when you type `/jev-check` | Asks four problem-hunting questions about the latest code change |

The check is deliberately **not** automatic. Nothing runs it for you.

## Files

| File | What it is |
| --- | --- |
| `route.py` | The `UserPromptSubmit` hook. Asks Jev four questions, then injects the decision as context. |
| `check.py` | The post-change check. Run by `/jev-check`; also runnable directly. |
| `skills.json` | The skill catalog the router chooses from: option name to one-line description. |
| `toggle.sh` | `on` / `off` / `status` / `last`. Backs the `/jev` slash command. |
| `state` | Holds `on` or `off` for the router. Starts `off`. Machine-local. |
| `last-decision.json` | The most recent routing decision, for debugging. Overwritten each time. Machine-local. |
| `statusline.py` | The Claude Code status line: folder, git branch, model, and `Jev: ON` or `Jev: off`. |

The hook and the status line are registered in `.claude/settings.local.json`,
which stays gitignored because it holds the API key. Claude Code reads hooks and
the status line at startup, so restart it after changing either registration.

---

# The router

## The four questions

Jev answers all four in one request, over the prompt text alone:

1. `needs_work` - does this need tools, or is it a conversational turn?
2. `needs_history` - would an agent with the repo but no chat history understand it?
3. `model` - opus, sonnet, or haiku.
4. `skill` - one entry from `skills.json`, or `none`.

## The two thresholds

Both live at the top of `route.py` and are the only numbers to adjust.

| Constant | Default | What it gates |
| --- | --- | --- |
| `DOWNGRADE_MIN_CONFIDENCE` | `0.6` | Handing work to a **cheaper** tier is the only decision that can go badly, so it is the only one gated. If Jev picks sonnet or haiku with confidence below this, the main conversation keeps the work instead. Nothing gates an opus verdict. |
| `HISTORY_UNSURE_BELOW` | `0.6` | How sure Jev must be that a prompt needs the conversation history before that cancels delegation. At or above it, the main conversation keeps the work. Below it the two options are near even, so the work is still delegated and the agent gets a thorough briefing instead. |

The **skill** choice is not gated at all: the highest-probability option always
wins, and `none` means no skill is loaded.

## The same-tier rule

When Jev's tier equals the tier the main conversation already runs at, the work
is **not** delegated - there is nothing to gain from handing opus work to an opus
agent. This is a plain equality check and nothing more. Whether same-tier work
is worth delegating for other reasons is an open question, to be settled by an
A/B test once sonnet is actually used as a main model.

### Keeping the main tier correct

`MAIN_CONVERSATION_TIER` at the top of `route.py` is that tier, and it defaults
to `opus`.

**A `UserPromptSubmit` payload does not carry the active model.** Verified
against the Claude Code hooks reference: the input is `session_id`,
`transcript_path`, `cwd`, `permission_mode`, `hook_event_name` and `prompt`
only. Only `SessionStart` may receive a `model` field, and there is no
`$CLAUDE_MODEL` environment variable. The status line gets a model, but a status
line is not a hook and its payload is a different shape.

So: **if you switch the main model with `/model`, edit
`MAIN_CONVERSATION_TIER` by hand to match.** Nothing detects it for you, and a
stale value only costs you the same-tier shortcut - the router keeps working.

`read_main_tier()` already prefers a payload field over the constant, checking
`model`, `current_model` and `active_model`, as a string or an object. If a
future Claude Code version starts sending one, it is picked up with no code
change. Until then the constant is what is used.

## How the answers map to behavior

In order; the first match wins.

1. `needs_work = no` - answer directly, no agent.
2. Jev's tier **equals** `MAIN_CONVERSATION_TIER` - do the work in the main
   conversation, no agent.
3. Jev picked a cheaper tier with confidence **below** `DOWNGRADE_MIN_CONFIDENCE`
   - too close to a coin flip to hand to a weaker model, so the main
   conversation keeps it.
4. `needs_history` **and** confidence at or above `HISTORY_UNSURE_BELOW` - a
   fresh agent cannot be given back the conversation, so the main conversation
   keeps it.
5. Otherwise - delegate to a `general-purpose` agent on the chosen tier. If Jev
   was undecided about history, the agent gets a thorough briefing.

The skill is applied in every one of these branches.

## Failure behavior

`route.py` prints nothing and exits 0 on every failure: switch off, slash
command, missing API key, network error, bad JSON, or a timeout over 12 seconds.
A prompt is never blocked by the router.

## Changing the skill list

Edit `skills.json`. Keys must be exact skill names as the Skill tool accepts
them, including any `plugin:skill` prefix. Descriptions are what Jev reads, so
describe the *situation* a skill is for, not the skill's name restated. Choice
allows up to 255 options.

---

# The check

## Running it

```
/jev-check                  # uncommitted work, falling back to the last commit
/jev-check HEAD~1 HEAD      # one specific commit
/jev-check main...HEAD      # the whole branch
python3 .claude/jev/check.py # same thing, without the slash command
```

Arguments are passed straight through to `git diff`.

With no arguments it collects **tracked edits plus brand-new untracked files**.
Untracked files come from `git ls-files --others --exclude-standard`, so
anything `.gitignore`, the global excludes file or `.git/info/exclude` hides is
never sent. Each new file is diffed against the null device so it reads as an
ordinary all-additions hunk. If there is nothing uncommitted at all, it falls
back to the last commit.

## The four questions

All four point the same way: **yes means there is a problem**, so a higher
number is always worse and there is no per-question direction to remember.

| Question | Asks |
| --- | --- |
| `weakened_test` | Does this change make the tests less able to catch a bug? |
| `swallowed_error` | Is an error caught and then silently ignored? |
| `hidden_side_effect` | Does any function do meaningfully more than its name says? |
| `stale_comment` | Is a comment left in place now contradicted by the code? |

## Reading the numbers

Each answer is a probability between 0 and 1 that the problem is present. There
is no pass or fail threshold - every probability is reported. The two band
edges are at the top of `check.py`.

| Band | Constant | Means |
| --- | --- | --- |
| above `0.7` | `LIKELY_PROBLEM_ABOVE` | Likely a problem. Go look. |
| `0.3` to `0.7` | - | Unsure: the probability is spread, so Jev is genuinely torn. Not "a medium problem". |
| below `0.3` | `PROBABLY_FINE_BELOW` | Probably fine. |

A noul answer has no separate confidence field, because a yes/no question has
only two outcomes and the single probability already describes it fully.

## Credentials are stripped first

Anything matching a credential shape is replaced with `[REDACTED]` before the
diff leaves this machine: credential-ish key names with a value, `Bearer`
tokens, vendor-prefixed keys such as `sk-`, `ghp_` and `xoxb-`, and PEM private
key bodies. The output reports how many replacements were made. The key name
itself is kept, so Jev can still see that a credential is being assigned.

The diff is capped at `MAX_DIFF_CHARS` (60,000) characters and the output says
when it was truncated. A change bigger than that should be checked file by file
rather than losing its tail.

## Two things to watch

**Big diffs dilute the signal.** The same stale-comment problem scored `0.17`
inside a 46,000-character diff and `0.35` when the one 476-character file was
sent alone. A clear problem in a small diff is spotted easily; the same problem
buried in a large one can fade into the unsure band. Prefer checking one commit
or one file at a time when you want a sharp answer.

**Rewording a question changes its scores.** When `name_matches_behaviour`
("does the name match?") was flipped to `hidden_side_effect` ("does anything
exceed its name?"), the same commit moved from `0.19` on the old wording -
a clear flag - to `0.49` on the new one, the unsure band. Flipped questions are
not mirror images: more specific criteria make Jev more conservative. **So after
editing any question's text, re-run the whole test set and compare, instead of
assuming the scores held.** `TEST_SET.md` is where that set lives once labelled.

## Cost

About 1.8k input tokens and 0.25 seconds for a one-file commit; about 15k input
tokens and 0.4 seconds for a 50,000-character diff. Output tokens are 78-81
regardless, because four yes/no answers are all that comes back.

---

# The switch button

`/Users/juvern/.claude/dev-mods/52e1dc2f-c53d-4db8-91ee-7f33decae54f/jev-switch/`
is a Claude Code mod that draws the router switch as a pressable control just
above the prompt. It does not hold the switch state itself: it reads and writes
this folder's `state` file, because the router runs as its own process and that
file is the only thing both sides can see.

The band appears only where `.claude/jev/state` exists, so the mod stays
invisible in other projects. Its path is built from the session's project root,
so it still works when Claude Code was started in a subdirectory.

`claude plugin test <mod folder>` presses the button and checks the file flipped.

# Status line

`Jev: ON` shows green, `Jev: off` shows dim, so the router state is visible
without asking. The script prints a line on any input: broken JSON, empty
stdin, or a directory outside a git repo all degrade to a shorter line rather
than failing. It is the one place that does receive the live model name, from
the status line payload's `model.display_name`.
