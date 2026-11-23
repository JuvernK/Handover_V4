"""Offline regressions for routing consequences, context, and outbound data."""

import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import jev_common as common
import route


def choice(names, selected, probability=0.85):
    names = tuple(names)
    if len(names) == 1:
        probability = 1.0
    rest = (1 - probability) / (len(names) - 1) if len(names) > 1 else 0
    return {
        "type": "choice", "choice": selected,
        "probabilities": {name: probability if name == selected else rest for name in names},
        "confidence": (probability - 1 / len(names)) / (1 - 1 / len(names)) if len(names) > 1 else 1.0,
    }


def answers(model="haiku", probability=0.85, risk="low", work="yes", history="self_contained", skill="none",
            workload="large", workload_probability=0.85, history_probability=0.85):
    return {
        "needs_work": choice(route.WORK_OPTIONS, work),
        "needs_history": choice(route.HISTORY_OPTIONS, history, history_probability),
        "model": choice(route.MODEL_OPTIONS, model, probability),
        "workload": choice(route.WORKLOAD_OPTIONS, workload, workload_probability),
        "risk": choice(route.RISK_OPTIONS, risk),
        "skill": choice(("none", "code-review", "update-config"), skill),
    }


class PolicyTests(unittest.TestCase):
    def setUp(self):
        self.config = dict(common.DEFAULT_CONFIG, auto_load_skills=[])

    def test_upgrade_is_not_blocked_by_old_point_six_gate(self):
        result = route.decide_route(answers(model="opus", probability=0.55, risk="elevated"), "sonnet", self.config)
        self.assertEqual((result["action"], result["selected_model"], result["reason"]), ("delegate", "opus", "upgrade"))

    def test_clear_large_low_risk_downgrade_delegates_to_project_worker(self):
        data = answers()
        result = route.decide_route(data, "opus", self.config)
        self.assertEqual((result["action"], result["selected_model"], result["reason"]), ("delegate", "haiku", "low_risk_downgrade"))
        self.assertIn('subagent_type="jev-haiku"', route.build_context(result, data))

    def test_small_workload_keeps_downgrade_on_main(self):
        # Briefing a worker for a one-step task costs more than doing it directly.
        for data in (answers(workload="small"), answers(workload="large", workload_probability=0.6)):
            with self.subTest(workload=data["workload"]["probabilities"]):
                result = route.decide_route(data, "opus", self.config)
                self.assertEqual((result["action"], result["reason"]), ("main", "small_workload"))

    def test_unclear_downgrade_stays_on_main(self):
        for data in (answers(probability=0.45), answers(history_probability=0.6)):
            with self.subTest():
                result = route.decide_route(data, "opus", self.config)
                self.assertEqual((result["action"], result["reason"]), ("main", "uncertain_downgrade"))

    def test_downgrade_gates_come_from_config(self):
        config = dict(self.config, downgrade_min_confidence=0.2, downgrade_min_probability=0.55)
        result = route.decide_route(answers(probability=0.45, workload_probability=0.6, history_probability=0.6), "opus", config)
        self.assertEqual(result["action"], "delegate")

    def test_upgrade_ignores_workload_and_downgrade_gates(self):
        result = route.decide_route(answers(model="opus", probability=0.4, workload="small"), "haiku", self.config)
        self.assertEqual((result["action"], result["selected_model"], result["reason"]), ("delegate", "opus", "upgrade"))
        self.assertIn('model="opus"', route.build_context(result, answers(model="opus")))

    def test_high_model_confidence_cannot_override_elevated_or_unknown_risk(self):
        for risk in ("elevated", "unknown"):
            with self.subTest(risk=risk):
                result = route.decide_route(answers(probability=1.0, risk=risk), "opus", self.config)
                self.assertEqual(result["reason"], "risk_blocks_downgrade")
                self.assertEqual(result["action"], "main")

    def test_missing_main_model_is_not_assumed_opus(self):
        result = route.decide_route(answers(model="opus"), None, self.config)
        self.assertEqual(result["reason"], "main_model_unknown")
        self.assertIsNone(result["selected_model"])

    def test_history_and_continuation_preserve_prior_task(self):
        result = route.decide_route(answers(model="opus", history="needs_history"), "sonnet", self.config)
        self.assertEqual(result["reason"], "history_required")
        result = route.decide_route(answers(work="no", skill="update-config"), "opus", self.config)
        self.assertEqual(result["reason"], "interpret_in_context")
        self.assertEqual(result["skill"]["mode"], "none")
        context = route.build_context(result, answers(work="no"))
        self.assertIn("Continue already authorized work", context)
        self.assertNotIn("do not spawn", context.lower())

    def test_defer_option_and_same_tier_do_not_delegate(self):
        for model, expected in (("defer_to_main", "defer"), ("sonnet", "main")):
            self.assertEqual(route.decide_route(answers(model=model), "sonnet", self.config)["action"], expected)

    def test_skill_is_suggestion_by_default_and_risky_skill_never_auto(self):
        result = route.decide_route(answers(skill="code-review"), "opus", self.config)
        self.assertEqual(result["skill"]["mode"], "suggested")
        config = dict(self.config, auto_load_skills=["code-review", "update-config"])
        self.assertEqual(route.decide_route(answers(skill="code-review"), "opus", config)["skill"]["mode"], "auto")
        risky = route.decide_route(answers(skill="update-config"), "opus", config)
        self.assertEqual((risky["skill"]["mode"], risky["reason"]), ("suggested", "risk_blocks_downgrade"))

    def test_advice_preserves_user_model_and_permissions_and_requires_full_brief(self):
        data = answers(model="sonnet")
        context = route.build_context(route.decide_route(data, "opus", self.config), data)
        for text in ("explicit model preference", "existing authorizations", "acceptance criteria", "prior decisions", "has not created or switched", "not a probability of correctness"):
            self.assertIn(text, context)


class PayloadTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name).resolve() / ".claude" / "jev"
        self.home.mkdir(parents=True)
        (self.home / "state").write_text("on\n")
        (self.home / "skills.json").write_text(json.dumps({"none": "None", "code-review": "Review code", "update-config": "Modify settings"}))
        self.payload = {"prompt": "Rename the local helper in sample.py and update its callers.", "session_id": "session-one", "model": "claude-opus-4-6"}
        self.result = {"model": "jev-1.13.0", "answers": answers(), "usage": {"input_tokens": 100, "output_tokens": 50}}
        self.key_patch = patch.object(route, "read_api_key", return_value="synthetic-test-key")
        self.key_patch.start()
        self.addCleanup(self.key_patch.stop)

    def event(self):
        return common.read_decision(self.home, "session-one")

    def test_one_call_contains_all_independent_questions_and_no_history(self):
        with patch.object(route, "call_jev", return_value=self.result) as call:
            context = route.route_payload(self.payload, self.home)
        self.assertIsNotNone(context)
        self.assertEqual(call.call_count, 1)
        args = call.call_args.args
        self.assertEqual(set(args[2]), {"needs_work", "needs_history", "model", "workload", "risk", "skill"})
        self.assertEqual(args[1], {"user_prompt": self.payload["prompt"]})
        self.assertIn("defer_to_main", args[2]["model"]["criteria"])
        self.assertIn("RealityKit", args[2]["model"]["criteria"]["opus"])
        self.assertIn("none", args[2]["skill"]["criteria"])
        raw = (self.home / "last-decision.json").read_text()
        self.assertNotIn(self.payload["prompt"], raw)
        self.assertNotIn("synthetic-test-key", raw)
        self.assertEqual(self.event()["main_tier"], "opus")

    def test_no_network_when_off_sensitive_too_large_or_key_missing(self):
        for case in ("off", "sensitive", "large", "missing_key"):
            with self.subTest(case=case), patch.object(route, "call_jev") as call:
                (self.home / "state").write_text("off" if case == "off" else "on")
                payload = dict(self.payload)
                if case == "sensitive":
                    payload["prompt"] = 'Review this config: password="abc123"'
                elif case == "large":
                    payload["prompt"] = "x" * 20001
                with patch.object(route, "read_api_key", return_value="" if case == "missing_key" else "synthetic-test-key"):
                    self.assertIsNone(route.route_payload(payload, self.home))
                call.assert_not_called()
                self.assertEqual(self.event()["status"], "skipped")

    def test_network_error_and_malformed_response_do_not_inject_or_log_body(self):
        for response in (None, {"answers": {}}, {"answers": dict(answers(), model={"choice": "injected-model"})}):
            with self.subTest(response=response), patch.object(route, "call_jev", return_value=response):
                self.assertIsNone(route.route_payload(self.payload, self.home))
                self.assertEqual(self.event()["status"], "error")
        with patch.object(route, "call_jev", side_effect=common.JevError("http_500", "private raw body!")):
            self.assertIsNone(route.route_payload(self.payload, self.home))
        self.assertNotIn("private raw body", (self.home / "last-decision.json").read_text())

    def test_off_during_response_suppresses_old_advice(self):
        def return_after_toggle(*_args):
            (self.home / "state").write_text("off")
            return self.result
        with patch.object(route, "call_jev", side_effect=return_after_toggle):
            self.assertIsNone(route.route_payload(self.payload, self.home))
        self.assertEqual(self.event()["reason"], "off")

    def test_single_none_catalog_omits_skill_question(self):
        (self.home / "skills.json").write_text('{"none":"No skill"}')
        result = dict(self.result, answers={k: v for k, v in answers().items() if k != "skill"})
        with patch.object(route, "call_jev", return_value=result) as call:
            self.assertIsNotNone(route.route_payload(self.payload, self.home))
        self.assertNotIn("skill", call.call_args.args[2])
        self.assertEqual(self.event()["skill"]["mode"], "none")

    def test_invalid_downgrade_gates_are_rejected(self):
        for value in (1.5, -0.1, "0.6", True):
            with self.subTest(value=value), patch.object(route, "call_jev") as call:
                (self.home / "config.json").write_text(json.dumps({"downgrade_min_confidence": value}))
                self.assertIsNone(route.route_payload(self.payload, self.home))
                call.assert_not_called()
                self.assertEqual(self.event()["reason"], "invalid_config")

    def test_redacted_input_disables_autoload(self):
        (self.home / "config.json").write_text(json.dumps({"sensitive_handling": "redact", "auto_load_skills": ["code-review"]}))
        result = dict(self.result, answers=answers(skill="code-review"))
        payload = dict(self.payload, prompt='Review the local example password="abc123".')
        with patch.object(route, "call_jev", return_value=result) as call:
            self.assertIsNotNone(route.route_payload(payload, self.home))
        self.assertNotIn("abc123", call.call_args.args[1]["user_prompt"])
        self.assertEqual(self.event()["skill"]["mode"], "suggested")


if __name__ == "__main__":
    unittest.main()
