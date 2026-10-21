"""Security-boundary regressions using local files and intercepted HTTP only."""

import datetime as dt
import email.message
import io
import json
import os
from pathlib import Path
import stat
import sys
import tempfile
import traceback
import unittest
from unittest import mock
import urllib.error
import urllib.request
import urllib.response

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import jev_common as common


class CommonBoundaryTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="jev common ")
        self.addCleanup(temporary.cleanup)
        # /var and /tmp may be symlinks on macOS. The code intentionally rejects
        # surprising symlink parents, so use the actual temporary directory.
        self.root = Path(temporary.name).resolve()
        self.home = self.root / ".claude" / "jev"
        self.home.mkdir(parents=True)
        self.config = common.load_config(self.home)

    def assert_code(self, code, function, *args, **kwargs):
        with self.assertRaises(common.JevError) as caught:
            function(*args, **kwargs)
        self.assertEqual(caught.exception.code, code)
        return caught.exception

    def questions(self):
        return {"route": {
            "type": "choice", "instructions": "Choose the matching category.",
            "criteria": {"first": "First category", "second": "Second category"},
        }}

    def opener(self, raw=b'{"answers": {}}'):
        response = mock.MagicMock()
        response.__enter__.return_value = response
        response.read.return_value = raw
        opener = mock.Mock()
        opener.open.return_value = response
        return opener, response

    def install_capabilities(self, **values):
        common.atomic_write_json(self.home / ".runtime" / "installation.json", values)

    def model_path(self, session):
        return self.home / ".runtime" / "models" / (common.session_key(session) + ".json")

    def test_quoted_credentials_are_redacted_in_full(self):
        examples = [
            ('password = "x"', 'password = "[REDACTED]"'),
            ('password = "two words"', 'password = "[REDACTED]"'),
            (r'password = "one\" remaining-secret"', 'password = "[REDACTED]"'),
            (r"password = 'one\' remaining-secret'", 'password = "[REDACTED]"'),
            ('"password": "true"', '"password": "[REDACTED]"'),
            ('password = "false"', 'password = "[REDACTED]"'),
            ('password = "null"', 'password = "[REDACTED]"'),
            ('password = "os.environ[PASS]"', 'password = "[REDACTED]"'),
            ('password = "os.getenv(SECRET)"', 'password = "[REDACTED]"'),
            ('password = "[REDACTED]still-secret"', 'password = "[REDACTED]"'),
            (r'passport = "A\" remaining-private-id"', 'passport = "[REDACTED]"'),
        ]
        for raw, expected in examples:
            with self.subTest(raw=raw):
                clean, counts = common.redact_sensitive(raw)
                self.assertEqual(clean, expected)
                self.assertGreater(sum(counts.values()), 0)

    def test_real_environment_expressions_are_not_secret_literals(self):
        examples = [
            'password = os.environ["PASSWORD"]',
            'api_key = os.getenv("TYPESAFE_API_KEY")',
            'token = process.env.ACCESS_TOKEN',
            'password = ${PASSWORD}',
            'password = $PASSWORD',
        ]
        for raw in examples:
            with self.subTest(raw=raw):
                clean, counts = common.redact_sensitive(raw)
                self.assertEqual(clean, raw)
                self.assertEqual(sum(counts.values()), 0)

    def test_redaction_is_idempotent_for_its_own_markers(self):
        raw = 'password="abc"\ncontact person@example.invalid\npassport="AB12"'
        clean, counts = common.redact_sensitive(raw)
        twice, new_counts = common.redact_sensitive(clean)
        self.assertGreater(sum(counts.values()), 0)
        self.assertEqual(twice, clean)
        self.assertEqual(sum(new_counts.values()), 0)

    def test_named_dictionary_secrets_are_screened_before_http(self):
        examples = [
            {"password": "xy"}, {"password": "true"},
            {"password": "os.environ[PASS]"},
            {"nested": [{"api_key": "a b"}]},
            {"passport": "AB12345"},
        ]
        for state in examples:
            with self.subTest(state=state), mock.patch.object(common.urllib.request, "build_opener") as build:
                self.assert_code("sensitive_content", common.call_jev, "fixture-key", state, self.questions(), self.config)
                build.assert_not_called()

    def test_named_numeric_private_identifiers_are_also_screened(self):
        for state in ({"password": 1234}, {"ssn": 123456789}, {"passport": 123456789}):
            with self.subTest(state=state), mock.patch.object(common.urllib.request, "build_opener") as build:
                self.assert_code("sensitive_content", common.call_jev, "fixture-key", state, self.questions(), self.config)
                build.assert_not_called()

    def test_catalog_instructions_descriptions_and_option_keys_are_screened(self):
        cases = []
        instructions = self.questions()
        instructions["route"]["instructions"] = 'Read this, password="xy"'
        cases.append(instructions)
        description = self.questions()
        description["route"]["criteria"]["first"] = "Contact person@example.invalid"
        cases.append(description)
        option_key = self.questions()
        option_key["route"]["criteria"] = {"person@example.invalid": "First", "second": "Second"}
        cases.append(option_key)
        cases.append({"person@example.invalid": self.questions()["route"]})
        for questions in cases:
            with self.subTest(questions=questions), mock.patch.object(common.urllib.request, "build_opener") as build:
                self.assert_code("sensitive_content", common.call_jev, "fixture-key", {"prompt": "ordinary task"}, questions, self.config)
                build.assert_not_called()

    def test_redact_mode_sends_only_sanitized_nested_values(self):
        config = dict(self.config, sensitive_handling="redact")
        state = {"password": "xy", "ssn": 123456789, "nested": [{"passport": "AB12345"}], "text": 'password="two words"'}
        questions = self.questions()
        questions["route"]["criteria"]["first"] = "Contact person@example.invalid"
        opener, response = self.opener()
        with mock.patch.object(common.urllib.request, "build_opener", return_value=opener):
            common.call_jev("fixture-key", state, questions, config)
        request = opener.open.call_args.args[0]
        sent = json.loads(request.data.decode("utf-8"))
        self.assertEqual(sent["state"]["password"], "[REDACTED]")
        self.assertEqual(sent["state"]["ssn"], "[REDACTED]")
        self.assertEqual(sent["state"]["nested"][0]["passport"], "[REDACTED]")
        self.assertNotIn("two words", request.data.decode("utf-8"))
        self.assertNotIn("person@example.invalid", request.data.decode("utf-8"))
        self.assertEqual(request.get_header("Authorization"), "Bearer fixture-key")

    def test_sensitive_identifying_keys_are_not_silently_renamed_in_redact_mode(self):
        config = dict(self.config, sensitive_handling="redact")
        with mock.patch.object(common.urllib.request, "build_opener") as build:
            self.assert_code("sensitive_content", common.call_jev, "fixture-key", {"person@example.invalid": "value"}, self.questions(), config)
            build.assert_not_called()

    def test_nonfinite_and_duplicate_json_is_rejected(self):
        raw_values = [
            'NaN', 'Infinity', '-Infinity', '1e400',
            '{"answers": {}, "answers": {}}',
            '{"answers": {"one": {"noul": 0.1, "noul": 0.9}}}',
        ]
        for raw in raw_values:
            with self.subTest(raw=raw):
                with self.assertRaises(ValueError):
                    common.parse_json(raw)
                opener, response = self.opener(raw.encode("utf-8"))
                with mock.patch.object(common.urllib.request, "build_opener", return_value=opener):
                    self.assert_code("invalid_response", common.call_jev, "fixture-key", {"prompt": "ordinary"}, self.questions(), self.config)

    def test_probability_validation_rejects_nonfinite_boolean_huge_and_out_of_range(self):
        for value in (float("nan"), float("inf"), -(10 ** 1000), 10 ** 1000, -0.1, 1.1, True, "0.9", None):
            with self.subTest(value_type=type(value).__name__):
                self.assert_code("invalid_response", common.validate_noul, {"type": "noul", "noul": value})
                answer = {"type": "choice", "choice": "yes", "confidence": 0.8, "probabilities": {"yes": value, "no": 0.1}}
                self.assert_code("invalid_response", common.validate_choice, answer, ("yes", "no"))

    def test_choice_validation_rejects_nonwinning_choices_and_unknown_options(self):
        examples = [
            {"type": "choice", "choice": "yes", "confidence": 0.8, "probabilities": {"yes": 0.1, "no": 0.9}},
            {"type": "choice", "choice": "other", "confidence": 0.8, "probabilities": {"yes": 0.9, "no": 0.1}},
            {"type": "choice", "choice": "yes", "confidence": 0.8, "probabilities": {"yes": 0.9}},
            {"type": "choice", "choice": "yes", "confidence": 0.8, "probabilities": {"yes": 0.9, "no": 0.9}},
        ]
        for answer in examples:
            with self.subTest(answer=answer):
                self.assert_code("invalid_response", common.validate_choice, answer, ("yes", "no"))

    def test_redirect_is_stopped_before_a_second_request_can_receive_credentials(self):
        requests = []

        class OfflineTransport(urllib.request.BaseHandler):
            handler_order = 100

            def https_open(self, request):
                requests.append((request.full_url, request.get_header("Authorization")))
                headers = email.message.Message()
                if len(requests) == 1:
                    headers["Location"] = "https://untrusted.example.invalid/collect"
                    response = urllib.response.addinfourl(io.BytesIO(b"redirect"), headers, request.full_url, 302)
                    response.msg = "Found"
                else:
                    response = urllib.response.addinfourl(io.BytesIO(b'{"answers": {}}'), headers, request.full_url, 200)
                    response.msg = "OK"
                return response

            http_open = https_open

        real_build_opener = urllib.request.build_opener

        def offline_opener(*handlers):
            return real_build_opener(urllib.request.ProxyHandler({}), *handlers, OfflineTransport())

        with mock.patch.object(common.urllib.request, "build_opener", side_effect=offline_opener):
            self.assert_code("redirect_refused", common.call_jev, "fixture-key", {"prompt": "ordinary"}, self.questions(), self.config)
        self.assertEqual(requests, [(common.API_ENDPOINT, "Bearer fixture-key")])

    def test_response_reads_are_bounded(self):
        opener, response = self.opener(b"x" * (common.MAX_JSON_BYTES + 1))
        with mock.patch.object(common.urllib.request, "build_opener", return_value=opener):
            self.assert_code("response_too_large", common.call_jev, "fixture-key", {"prompt": "ordinary"}, self.questions(), self.config)
        response.read.assert_called_once_with(common.MAX_JSON_BYTES + 1)

    def test_http_errors_do_not_read_or_expose_raw_diagnostics(self):
        class UnreadableBody(io.BytesIO):
            def read(self, *unused):
                raise AssertionError("HTTP error body must not be read")

        body = UnreadableBody(b"PRIVATE_HTTP_BODY")
        error = urllib.error.HTTPError(common.API_ENDPOINT, 401, "PRIVATE_HTTP_REASON", {}, body)
        opener = mock.Mock()
        opener.open.side_effect = error
        with mock.patch.object(common.urllib.request, "build_opener", return_value=opener):
            raised = self.assert_code("http_401", common.call_jev, "fixture-key", {"prompt": "ordinary"}, self.questions(), self.config)
        visible = "".join(traceback.format_exception(type(raised), raised, raised.__traceback__))
        self.assertNotIn("PRIVATE_HTTP", visible)
        self.assertNotIn("PRIVATE_HTTP", raised.detail)
        self.assertTrue(body.closed)

    def test_invalid_or_oversized_switch_content_is_off(self):
        state = self.home / "state"
        self.assertFalse(common.is_enabled(self.home))
        state.write_text("on\n", encoding="utf-8")
        self.assertTrue(common.is_enabled(self.home))
        for raw in ("off", "ON", "true", "on\0", "on\n" + " " * 1000, "on" + "x" * 1000):
            with self.subTest(raw=repr(raw[:20])):
                state.write_text(raw, encoding="utf-8")
                self.assertFalse(common.is_enabled(self.home))

    def test_symlinked_switch_is_off(self):
        other = self.root / "other-state"
        other.write_text("on", encoding="utf-8")
        self.home.joinpath("state").symlink_to(other)
        self.assertFalse(common.is_enabled(self.home))

    def test_atomic_writes_are_private_and_replace_existing_content(self):
        target = self.home / ".runtime" / "nested" / "record.json"
        common.atomic_write_json(target, {"version": 1})
        self.assertEqual(stat.S_IMODE(target.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(target.parent.stat().st_mode), 0o700)
        self.assertEqual(stat.S_IMODE(target.parent.parent.stat().st_mode), 0o700)
        target.chmod(0o666)
        common.atomic_write_json(target, {"version": 2})
        self.assertEqual(json.loads(target.read_text(encoding="utf-8")), {"version": 2})
        self.assertEqual(stat.S_IMODE(target.stat().st_mode), 0o600)
        self.assertEqual(list(target.parent.glob(".jev-write-*")), [])

    def test_atomic_write_rejects_symlink_target_and_parent(self):
        outside = self.root / "outside"
        outside.mkdir()
        original = outside / "original.txt"
        original.write_text("preserve", encoding="utf-8")
        link = self.home / "link"
        link.symlink_to(outside, target_is_directory=True)
        self.assert_code("unsafe_path", common.atomic_write_text, link / "new.txt", "forbidden")
        self.assertFalse(outside.joinpath("new.txt").exists())
        file_link = self.home / "file-link.txt"
        file_link.symlink_to(original)
        self.assert_code("unsafe_path", common.atomic_write_text, file_link, "forbidden")
        self.assertEqual(original.read_text(encoding="utf-8"), "preserve")

    def test_model_normalization_accepts_known_families_without_substring_guesses(self):
        valid = {
            "opus": "opus", "Claude Sonnet 4.6": "sonnet",
            "claude-sonnet-4-5-20250929": "sonnet", "claude-3-5-haiku-20241022": "haiku",
            "opus[1m]": "opus", "claude-opus-4-7": "opus",
        }
        for name, expected in valid.items():
            with self.subTest(name=name):
                self.assertEqual(common.model_tier(name), expected)
        for name in ("not-opus", "my-opus-model", "gpt-opus", "Claude Fable 5.1", "random sonnet phrase"):
            with self.subTest(name=name):
                self.assertIsNone(common.model_tier(name))
        self.assertEqual(common.model_tier({"id": "claude-haiku-4-5", "display_name": "Opus"}), "haiku")
        self.assertIsNone(common.model_tier({"id": "unknown-provider-model", "display_name": "Opus"}))

    def test_fresh_session_models_need_a_verified_tracking_capability(self):
        common.remember_main_model(self.home, "session-a", "opus", source="SessionStart")
        self.assertEqual(common.resolve_main_tier({"session_id": "session-a"}, self.config, self.home), (None, "unknown"))
        self.install_capabilities(post_model_switch=False, own_statusline=False)
        self.assertEqual(common.resolve_main_tier({"session_id": "session-a"}, self.config, self.home), (None, "unknown"))
        self.install_capabilities(post_model_switch=True, own_statusline=False)
        self.assertEqual(common.resolve_main_tier({"session_id": "session-a"}, self.config, self.home), ("opus", "session_tracking"))
        self.install_capabilities(post_model_switch=False, own_statusline=True)
        self.assertEqual(common.resolve_main_tier({"session_id": "session-a"}, self.config, self.home), ("opus", "session_tracking"))

    def test_unknown_current_model_invalidates_old_known_cache_and_config(self):
        self.install_capabilities(post_model_switch=True)
        common.remember_main_model(self.home, "session-a", "opus")
        configured = dict(self.config, main_tier="sonnet")
        self.assertEqual(common.resolve_main_tier({"session_id": "session-a", "model": "new-unknown-model"}, configured, self.home), (None, "payload"))
        common.remember_main_model(self.home, "session-a", "new-unknown-model")
        self.assertEqual(common.resolve_main_tier({"session_id": "session-a"}, configured, self.home), (None, "tracked_unknown"))
        record = json.loads(self.model_path("session-a").read_text(encoding="utf-8"))
        self.assertIsNone(record["tier"])
        self.assertNotIn("new-unknown-model", json.dumps(record))

    def test_stale_or_future_cache_cannot_override_explicit_config(self):
        self.install_capabilities(post_model_switch=True)
        configured = dict(self.config, main_tier="sonnet")
        common.remember_main_model(self.home, "session-a", "opus")
        path = self.model_path("session-a")
        record = json.loads(path.read_text(encoding="utf-8"))
        for delta in (dt.timedelta(days=-2), dt.timedelta(days=2)):
            with self.subTest(delta=delta):
                when = dt.datetime.now(dt.timezone.utc) + delta
                record["timestamp"] = when.isoformat().replace("+00:00", "Z")
                common.atomic_write_json(path, record)
                self.assertEqual(common.resolve_main_tier({"session_id": "session-a"}, configured, self.home), ("sonnet", "explicit_config"))
                self.assertEqual(common.resolve_main_tier({"session_id": "session-a"}, self.config, self.home), (None, "unknown"))

    def test_session_models_are_isolated_and_use_safe_paths(self):
        self.install_capabilities(post_model_switch=True)
        sessions = {"session-a": "opus", "../session-b/../../escape": "haiku"}
        for session, model in sessions.items():
            common.remember_main_model(self.home, session, model)
            self.assertEqual(common.resolve_main_tier({"session_id": session}, self.config, self.home), (model, "session_tracking"))
        self.assertEqual(common.resolve_main_tier({"session_id": "session-c"}, self.config, self.home), (None, "unknown"))
        files = list((self.home / ".runtime" / "models").iterdir())
        self.assertEqual(len(files), 2)
        for path in files:
            self.assertRegex(path.name, r"^[a-f0-9]{24}\.json$")
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
        self.assertFalse(self.root.joinpath("escape").exists())


if __name__ == "__main__":
    unittest.main()
