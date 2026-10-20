#!/usr/bin/env python3
"""Jev post-change check: four yes/no questions about the latest code change.

Collects the current diff, strips anything that looks like a credential, then
asks Jev all four questions in a single request so they run in parallel.

All four questions point the same way: yes means there is a problem. So the
returned probability is always the probability that something is wrong, and a
low number is always the healthy answer.

Run directly: python3 .claude/jev/check.py [git-diff-args...]
With no arguments it checks uncommitted work, falling back to the last commit.
"""

import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
CLAUDE_DIR = os.path.dirname(HERE)
REPO_DIR = os.path.dirname(CLAUDE_DIR)
ENDPOINT = "https://api.typesafe.ai/v1/systemone"
TIMEOUT_SECONDS = 60
# Jev sees a bounded slice of the diff; a change larger than this needs
# splitting by file rather than silently losing its tail.
MAX_DIFF_CHARS = 60000
REDACTED = "[REDACTED]"

# Reporting bands, grouped here so they are easy to adjust. These label the
# answer; they do not gate anything, so every probability is always reported.
LIKELY_PROBLEM_ABOVE = 0.7
PROBABLY_FINE_BELOW = 0.3

# Each pattern keeps the part that identifies the field and replaces only the
# secret itself, so Jev still sees that a credential is being assigned.
SECRET_PATTERNS = [
    # key: "value" / key = 'value' / KEY=value, for credential-ish key names.
    # The key name may carry a prefix and a closing quote of its own, as in
    # "TYPESAFE_API_KEY": "...", so both sides are allowed for.
    re.compile(
        r"""(?ix)
        ( [a-z0-9_-]*
          (?:api[_-]?key|apikey|secret|token|password|passwd|credential|auth)
          [a-z0-9_-]* ["']? \s* [:=] \s* ["']? )
        [^\s"',;}]{8,}
        """,
    ),
    # Authorization: Bearer <token>
    re.compile(r"(?i)(bearer\s+)[A-Za-z0-9._\-]{12,}"),
    # Common vendor-prefixed keys
    re.compile(r"\b((?:sk|pk|ghp|gho|ghs|ghu|xox[baprs])[-_])[A-Za-z0-9_\-]{12,}"),
    # PEM private key bodies
    re.compile(
        r"(-----BEGIN [A-Z ]*PRIVATE KEY-----)[\s\S]*?(-----END [A-Z ]*PRIVATE KEY-----)"
    ),
]


def redact(text):
    """Replace credential-looking values. Returns (clean_text, hit_count)."""
    hits = 0
    for pattern in SECRET_PATTERNS:
        groups = pattern.groups
        if groups >= 2:
            replacement = r"\1" + REDACTED + r"\2"
        else:
            replacement = r"\1" + REDACTED
        text, count = pattern.subn(replacement, text)
        hits += count
    return text, hits


def read_api_key():
    key = os.environ.get("TYPESAFE_API_KEY", "").strip()
    if key:
        return key
    try:
        with open(os.path.join(CLAUDE_DIR, "settings.local.json")) as fh:
            return json.load(fh).get("env", {}).get("TYPESAFE_API_KEY", "").strip()
    except (OSError, ValueError):
        return ""


def git(*args):
    return subprocess.run(
        ("git",) + args,
        cwd=REPO_DIR,
        capture_output=True,
        text=True,
        check=False,
    ).stdout


def untracked_paths():
    """New files git does not track yet, with .gitignore'd ones left out.

    --exclude-standard is what applies .gitignore, the global excludes file and
    .git/info/exclude, so an ignored file never reaches Jev. -z keeps paths with
    spaces in one piece.
    """
    listing = git("ls-files", "--others", "--exclude-standard", "-z")
    return [path for path in listing.split("\0") if path]


def untracked_diff():
    """A unified diff that presents each untracked file as newly added."""
    chunks = []
    for path in untracked_paths():
        # Diffing against the null device is what turns a file git has never
        # seen into an ordinary all-additions hunk.
        chunks.append(git("diff", "--no-index", "--", os.devnull, path))
    return "".join(chunks)


def collect_diff(extra_args):
    """Return (diff_text, label) for whatever counts as the latest change."""
    if extra_args:
        return git("diff", *extra_args), "git diff " + " ".join(extra_args)

    tracked = git("diff", "HEAD")
    new_files = untracked_paths()
    untracked = untracked_diff() if new_files else ""
    if tracked.strip() or untracked.strip():
        label = "uncommitted changes"
        if new_files:
            label += ", including %d new untracked file%s (%s)" % (
                len(new_files),
                "" if len(new_files) == 1 else "s",
                ", ".join(new_files[:5]) + (", ..." if len(new_files) > 5 else ""),
            )
        return tracked + untracked, label

    return git("show", "--format=", "HEAD"), "the last commit (%s)" % git(
        "log", "-1", "--format=%h %s"
    ).strip()


QUESTIONS = {
    "weakened_test": {
        "type": "noul",
        "instructions": (
            "`diff` is a unified diff of a code change. Does this change make the "
            "test suite less able to catch a bug than it was before?"
        ),
        "criteria": {
            "true": (
                "An assertion was deleted, an expected value was loosened to match "
                "whatever the code now returns, a test was skipped, disabled, "
                "commented out or marked as expected-to-fail, a test body was "
                "emptied, or an assertion was downgraded to a print or log call"
            ),
            "false": (
                "Tests were only renamed, moved, reformatted, or updated to follow a "
                "deliberate API change while still asserting the same behaviour; or "
                "tests were added; or the diff does not touch tests at all"
            ),
        },
    },
    "swallowed_error": {
        "type": "noul",
        "instructions": (
            "`diff` is a unified diff of a code change. In the lines this change "
            "adds, is an error caught and then silently ignored, so that a failure "
            "would leave no trace and the caller could not tell it happened?"
        ),
        "criteria": {
            "true": (
                "An added catch, rescue, except or error branch has an empty body, "
                "holds only a comment, or discards the error and returns a normal "
                "looking value such as nil, empty or false without logging it, "
                "rethrowing it, or signalling failure to the caller"
            ),
            "false": (
                "Every added error branch logs the error, rethrows or wraps it, "
                "returns an explicit failure the caller must handle, or deliberately "
                "falls back with a comment explaining why ignoring it is correct; or "
                "the diff adds no error handling"
            ),
        },
    },
    "hidden_side_effect": {
        "type": "noul",
        "instructions": (
            "`diff` is a unified diff of a code change. Does any function the change "
            "adds or modifies do meaningfully more than its name says it does?"
        ),
        "criteria": {
            "true": (
                "At least one added or changed function reaches beyond its name: a "
                "name reading as a pure lookup or computation, such as get, fetch, "
                "compute, position or validate, that also writes a file, persists "
                "data, mutates shared or global state, sends a network request, "
                "mutates its arguments, or flips a flag the caller would not expect; "
                "or a name naming one action for a function that also returns a "
                "separately meaningful result the name never mentions"
            ),
            "false": (
                "Every added or changed function's name covers its real work, so a "
                "reader seeing only the name would not be surprised by anything the "
                "body does; or the diff adds or changes no functions"
            ),
        },
    },
    "stale_comment": {
        "type": "noul",
        "instructions": (
            "`diff` is a unified diff of a code change. Is any comment left next to "
            "the changed lines now contradicted by the code around it?"
        ),
        "criteria": {
            "true": (
                "At least one comment or documentation comment that the change left "
                "in place now names a parameter, return value, default, unit, "
                "ordering, condition or step that the change renamed, removed, "
                "reordered, inverted or replaced"
            ),
            "false": (
                "Every nearby comment still describes what the surrounding code does, "
                "or comments were updated along with the code, or there are no "
                "comments near the changed lines"
            ),
        },
    },
}


def band(probability):
    """Label a problem probability without gating on it."""
    if probability is None:
        return "no answer"
    if probability > LIKELY_PROBLEM_ABOVE:
        return "likely a problem"
    if probability < PROBABLY_FINE_BELOW:
        return "probably fine"
    return "unsure (probability is spread)"


def main():
    diff_text, label = collect_diff(sys.argv[1:])
    if not diff_text.strip():
        print("No code change found to check: the working tree is clean and HEAD has "
              "no diff.")
        return 1

    clean_diff, redactions = redact(diff_text)
    truncated = len(clean_diff) > MAX_DIFF_CHARS
    if truncated:
        clean_diff = clean_diff[:MAX_DIFF_CHARS]

    api_key = read_api_key()
    if not api_key:
        print("TYPESAFE_API_KEY is not set, so Jev could not be asked.")
        return 1

    body = {
        "model": "jev-latest",
        "state": {"diff": clean_diff},
        "questions": QUESTIONS,
    }
    request = urllib.request.Request(
        ENDPOINT,
        data=json.dumps(body).encode("utf-8"),
        headers={
            "Authorization": "Bearer " + api_key,
            "Content-Type": "application/json",
        },
        method="POST",
    )

    started = time.monotonic()
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
            result = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        print("Jev returned HTTP %s: %s" % (error.code, error.read().decode("utf-8", "replace")[:500]))
        return 1
    except (urllib.error.URLError, OSError, ValueError, TimeoutError) as error:
        print("Could not reach Jev: %s" % error)
        return 1
    elapsed_ms = (time.monotonic() - started) * 1000

    answers = result.get("answers", {})
    report = {}
    for name in QUESTIONS:
        probability = answers.get(name, {}).get("noul")
        report[name] = {
            "problem_probability": probability,
            "reading": band(probability),
        }

    print(json.dumps(
        {
            "checked": label,
            "diff_chars_sent": len(clean_diff),
            "diff_truncated": truncated,
            "secrets_redacted": redactions,
            "model": result.get("model"),
            "elapsed_ms": round(elapsed_ms, 1),
            "usage": result.get("usage", {}),
            "direction": "every question asks whether there is a problem, so a "
                         "higher probability is worse",
            "bands": {
                "likely a problem": "> %.2f" % LIKELY_PROBLEM_ABOVE,
                "unsure (probability is spread)": "%.2f to %.2f" % (
                    PROBABLY_FINE_BELOW, LIKELY_PROBLEM_ABOVE),
                "probably fine": "< %.2f" % PROBABLY_FINE_BELOW,
            },
            "answers": report,
        },
        indent=2,
    ))
    return 0


if __name__ == "__main__":
    sys.exit(main())
