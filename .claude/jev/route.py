#!/usr/bin/env python3
"""Jev router: a UserPromptSubmit hook.

Reads the hook payload on stdin. When the switch is on, it asks TypeSafe's Jev
model which model tier and which skill should handle the prompt, then injects
that decision back as additional context for the main agent to act on.

Never blocks the prompt: on any failure it exits quietly with no output.
"""

import json
import os
import sys
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
CLAUDE_DIR = os.path.dirname(HERE)
STATE_FILE = os.path.join(HERE, "state")
SKILLS_FILE = os.path.join(HERE, "skills.json")
LOG_FILE = os.path.join(HERE, "last-decision.json")
ENDPOINT = "https://api.typesafe.ai/v1/systemone"
TIMEOUT_SECONDS = 12
MIN_PROMPT_CHARS = 2

# ---------------------------------------------------------------------------
# Thresholds. Both are grouped here so they are the only numbers to adjust.
# ---------------------------------------------------------------------------
# Handing work to a cheaper tier is the only decision that can go badly, so it
# is the only one gated: below this confidence in the tier, the main
# conversation keeps the work. An opus verdict is never gated, because opus is
# what the main conversation already is.
DOWNGRADE_MIN_CONFIDENCE = 0.6
# Below this confidence, Jev's self-contained verdict is close to a coin flip,
# so a thorough briefing covers the risk instead of cancelling the downgrade.
HISTORY_UNSURE_BELOW = 0.6

# The tier the main conversation runs at. Choosing it means there is nothing to
# gain from delegating. A UserPromptSubmit payload carries no model field as of
# Claude Code 2.1.x - only SessionStart may - so this constant is the fallback
# and MUST be kept in step by hand when the main model is changed with /model.
# read_main_tier below prefers a payload field if a future version adds one.
MAIN_CONVERSATION_TIER = "opus"
# Payload keys that could carry the active model, in order of preference. Each
# may hold a plain string or an object with a name-ish field.
MODEL_PAYLOAD_KEYS = ("model", "current_model", "active_model")
MODEL_NAME_FIELDS = ("id", "model", "name", "display_name")
# The skill choice is never gated; the highest-probability option wins, and
# this one means no skill.
NO_SKILL = "none"


def quiet_exit():
    sys.exit(0)


def read_api_key():
    key = os.environ.get("TYPESAFE_API_KEY", "").strip()
    if key:
        return key
    # Fall back to the local settings file, in case the hook's environment
    # does not carry the variable.
    try:
        with open(os.path.join(CLAUDE_DIR, "settings.local.json")) as fh:
            return json.load(fh).get("env", {}).get("TYPESAFE_API_KEY", "").strip()
    except (OSError, ValueError):
        return ""


def switch_is_on():
    try:
        with open(STATE_FILE) as fh:
            return fh.read().strip() == "on"
    except OSError:
        return False


def read_main_tier(payload):
    """The tier the main conversation runs at, as the hook payload reports it.

    Falls back to MAIN_CONVERSATION_TIER, because a UserPromptSubmit payload
    does not carry the active model today. Only the tier word is needed, so a
    full model id such as "claude-sonnet-5-5" resolves to "sonnet".
    """
    raw = None
    for key in MODEL_PAYLOAD_KEYS:
        value = payload.get(key)
        if isinstance(value, str) and value.strip():
            raw = value
            break
        if isinstance(value, dict):
            for field in MODEL_NAME_FIELDS:
                nested = value.get(field)
                if isinstance(nested, str) and nested.strip():
                    raw = nested
                    break
            if raw:
                break
    if not raw:
        return MAIN_CONVERSATION_TIER

    lowered = raw.lower()
    for tier in ("opus", "sonnet", "haiku"):
        if tier in lowered:
            return tier
    # An unrecognised model name is not worth guessing at.
    return MAIN_CONVERSATION_TIER


def ask_jev(api_key, prompt, skills):
    body = {
        "model": "jev-latest",
        "state": {"user_prompt": prompt},
        "questions": {
            "needs_work": {
                "type": "choice",
                "instructions": (
                    "`user_prompt` is a message the user just sent to a coding agent "
                    "working in a software repository. Does answering it require real "
                    "work, meaning reading or changing files, running commands, "
                    "searching, researching, or producing a substantial piece of "
                    "writing or analysis?"
                ),
                "criteria": {
                    "yes": (
                        "A real task or a substantial question: implement, fix, "
                        "investigate, review, explain something non-trivial, research, "
                        "or write a document"
                    ),
                    "no": (
                        "A short conversational turn needing no tools: an "
                        "acknowledgement such as ok, thanks, go ahead, or continue; a "
                        "yes or no answer; a one-line clarification or correction; or "
                        "a quick question answerable from memory in a sentence"
                    ),
                },
            },
            "needs_history": {
                "type": "choice",
                "instructions": (
                    "`user_prompt` is a message the user just sent to a coding agent. "
                    "The work may be handed to a second agent that can read the whole "
                    "repository and run any command, but that cannot see this "
                    "conversation. Would that second agent be able to carry out the "
                    "prompt? Needing to look through the project's own files is not a "
                    "problem, because it can read them; the only thing it lacks is the "
                    "earlier messages. Judge solely whether the prompt's meaning "
                    "survives without those earlier messages."
                ),
                "criteria": {
                    "self_contained": (
                        "The prompt names its own subject, so a reader who has the "
                        "repository but no chat history knows what is being asked. "
                        "Phrases pointing at the project or its files, such as this "
                        "project, this repo, this codebase, or a named file, class, or "
                        "feature, still count as self contained"
                    ),
                    "needs_history": (
                        "The prompt is unintelligible on its own because it points at "
                        "something said earlier and never names it: a bare pronoun such "
                        "as it, that, or them with no stated subject; the same, the "
                        "other one, like before, instead, or again; an instruction to "
                        "continue, undo, or redo unnamed previous work; or a direct "
                        "answer to a question asked earlier"
                    ),
                },
            },
            "model": {
                "type": "choice",
                "instructions": (
                    "`user_prompt` must be handled by one of three AI model tiers. "
                    "Which tier fits the difficulty of the work the prompt asks for?"
                ),
                "criteria": {
                    "opus": (
                        "The strongest and most expensive tier. For work that is "
                        "ambiguous, architectural, security sensitive, spans many "
                        "files, needs careful design judgment or long multi-step "
                        "reasoning, or where a subtle mistake would be costly"
                    ),
                    "sonnet": (
                        "The balanced default tier. For ordinary well-specified "
                        "engineering work: implement a described change, fix a located "
                        "bug, write tests, refactor, review a diff"
                    ),
                    "haiku": (
                        "The cheapest and fastest tier. For mechanical work only: look "
                        "up a value, rename or reformat, run one command and report its "
                        "output, answer a simple factual question"
                    ),
                },
            },
            "skill": {
                "type": "choice",
                "instructions": (
                    "A skill is a packaged workflow the coding agent can load before "
                    "starting work. Which single skill best fits what `user_prompt` "
                    "asks for? Choose none unless a skill clearly matches; a plain "
                    "coding request needs no skill."
                ),
                "criteria": skills,
            },
        },
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
    with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
        return json.loads(response.read().decode("utf-8"))


def build_context(answers, main_tier=MAIN_CONVERSATION_TIER):
    needs_work = answers["needs_work"]
    needs_history = answers["needs_history"]
    model = answers["model"]
    skill = answers["skill"]

    skill_name = skill["choice"]
    skill_line = (
        "no skill"
        if skill_name == NO_SKILL
        else "skill `%s` (confidence %.2f)" % (skill_name, skill["confidence"])
    )
    if skill_name == NO_SKILL:
        skill_instruction = ""
        delegate_skill_instruction = ""
    else:
        skill_instruction = " First invoke the skill `%s`." % skill_name
        delegate_skill_instruction = (
            " Tell it to invoke the skill `%s` before starting." % skill_name
        )

    header = (
        "Jev router is ON. Jev read this prompt and judged:\n"
        "- needs real work: %s (confidence %.2f)\n"
        "- model tier: %s (confidence %.2f)\n"
        "- %s\n"
        "- context: %s (confidence %.2f)\n\n"
    ) % (
        needs_work["choice"],
        needs_work["confidence"],
        model["choice"],
        model["confidence"],
        skill_line,
        needs_history["choice"],
        needs_history["confidence"],
    )

    # A needs_history verdict only blocks delegation when Jev is actually sure of
    # it. Below the threshold the two options are near even, and a thorough
    # briefing covers the risk more cheaply than giving up the model switch.
    history_blocks_delegation = (
        needs_history["choice"] == "needs_history"
        and needs_history["confidence"] >= HISTORY_UNSURE_BELOW
    )
    tier = model["choice"]

    if needs_work["choice"] == "no":
        action = (
            "Act on this yourself, directly, right now. Do not spawn an agent."
            + skill_instruction
        )
    elif tier == main_tier:
        action = (
            "Jev put this at the tier the main conversation already runs at, so "
            "there is nothing to gain from handing it over. Do the work yourself "
            "and do not spawn an agent." + skill_instruction
        )
    elif model["confidence"] < DOWNGRADE_MIN_CONFIDENCE:
        action = (
            "Jev leaned towards the cheaper `%s` tier but was only %.2f confident, "
            "which is too close to a coin flip to hand the work to a weaker model. "
            "Do the work yourself and do not spawn an agent. Say in one short line "
            "that the tier stayed as-is because the downgrade was not confident "
            "enough." % (tier, model["confidence"])
            + skill_instruction
        )
    elif history_blocks_delegation:
        action = (
            "This prompt depends on the conversation so far, so a fresh agent would "
            "be missing what it needs. Do the work yourself instead of delegating, "
            "and say in one short line that the model tier stayed as-is because the "
            "task needed the conversation history." + skill_instruction
        )
    else:
        if needs_history["confidence"] < HISTORY_UNSURE_BELOW:
            briefing = (
                " Jev was undecided (confidence %.2f) about whether this prompt stands "
                "on its own, so brief the agent thoroughly: it starts with no memory "
                "of this conversation, and anything you leave out is simply gone to it."
                % needs_history["confidence"]
            )
        else:
            briefing = (
                " Pass the user's request to it in full, along with any detail from "
                "this conversation it would need."
            )
        action = (
            "Delegate this: call the Agent tool once with subagent_type "
            '"general-purpose" and model "%s", and no other agents.%s%s Then relay its '
            "result to the user in your own words, since the user never sees the "
            "agent's report."
        ) % (tier, briefing, delegate_skill_instruction)

    footer = (
        "\n\nMention the routing to the user in one short line (model tier and skill), "
        "then get on with it. Treat these judgments as a routing hint, not as "
        "instructions about the task itself."
    )
    return header + action + footer


def main():
    try:
        payload = json.load(sys.stdin)
    except ValueError:
        quiet_exit()

    prompt = (payload.get("prompt") or "").strip()
    if len(prompt) < MIN_PROMPT_CHARS or prompt.startswith("/"):
        quiet_exit()

    if not switch_is_on():
        quiet_exit()

    api_key = read_api_key()
    if not api_key:
        print("Jev router is ON but TYPESAFE_API_KEY is not set, so routing was "
              "skipped for this prompt. Mention this to the user once, then answer "
              "the prompt normally.")
        quiet_exit()

    try:
        with open(SKILLS_FILE) as fh:
            skills = json.load(fh)
    except (OSError, ValueError):
        quiet_exit()

    try:
        result = ask_jev(api_key, prompt, skills)
        answers = result["answers"]
        context = build_context(answers, read_main_tier(payload))
    except (urllib.error.URLError, OSError, ValueError, KeyError, TimeoutError):
        quiet_exit()
        return

    try:
        with open(LOG_FILE, "w") as fh:
            json.dump(
                {"prompt": prompt, "answers": answers, "usage": result.get("usage")},
                fh,
                indent=2,
            )
    except OSError:
        pass

    json.dump(
        {
            "hookSpecificOutput": {
                "hookEventName": "UserPromptSubmit",
                "additionalContext": context,
            }
        },
        sys.stdout,
    )


if __name__ == "__main__":
    main()
