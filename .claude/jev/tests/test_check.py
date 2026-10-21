"""Checker smoke tests with temporary repositories and a mocked Jev client."""

import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import check
from jev_common import JevError


class CheckerTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="jev checker ")
        self.addCleanup(self.temporary.cleanup)
        # macOS keeps temp folders under /var, a symlink, which the path guard refuses.
        self.repo = Path(self.temporary.name).resolve()
        self.home = self.repo / ".claude" / "jev"
        self.home.mkdir(parents=True)
        self.config = {
            "jev_model": "jev-1.13.0", "sensitive_handling": "skip",
            "max_diff_chars": 60000, "git_timeout_seconds": 3,
            "exclude_globs": [],
        }
        self.git("init", "-q")
        self.git("config", "user.name", "Local Test")
        self.git("config", "user.email", "test@example.invalid")
        self.write(".gitignore", ".claude/\n")
        self.write("Sources/Reminder.swift", "let value = 1\n")
        self.git("add", ".gitignore", "Sources/Reminder.swift")
        self.git("commit", "-qm", "initial")
        self.write("Sources/Reminder.swift", "let value = 2\n")
        self.home.joinpath("state").write_text("on\n", encoding="utf-8")

    def git(self, *arguments):
        return subprocess.run(
            ["git"] + list(arguments), cwd=self.repo, check=True,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            env=dict(os.environ, GIT_CONFIG_NOSYSTEM="1"),
        ).stdout

    def write(self, relative, text):
        path = self.repo / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def response(self, probability=0.1):
        return {
            "answers": {name: {"type": "noul", "noul": probability} for name in check.QUESTIONS},
            "usage": {"input_tokens": 12, "output_tokens": 4},
        }

    def run_check(self, arguments=(), response=None, error=None, redactor=None):
        stream = io.StringIO()
        with mock.patch.object(check, "load_config", return_value=self.config), \
                mock.patch.object(check, "read_api_key", return_value="test-key-not-a-real-credential"), \
                mock.patch.object(check, "call_jev", return_value=response or self.response(), side_effect=error) as api:
            if redactor is not None:
                with mock.patch.object(check, "redact_sensitive", side_effect=redactor):
                    code = check.main(list(arguments), home=self.home, stream=stream)
            else:
                code = check.main(list(arguments), home=self.home, stream=stream)
        return code, json.loads(stream.getvalue()), api

    def test_default_preview_uses_no_api_and_excludes_untracked(self):
        self.write("new.txt", "new text\n")
        code, report, api = self.run_check()
        self.assertEqual(code, 0)
        self.assertEqual(report["status"], "preview")
        self.assertIn("+let value = 2", report["diff_preview"])
        self.assertNotIn("new.txt", report["files"])
        self.assertFalse(report["tests_run"])
        api.assert_not_called()

    def test_explicit_untracked_and_path_with_spaces(self):
        self.write("Sources/new file.swift", "let added = true\n")
        code, report, api = self.run_check(["--include-untracked", "--", "Sources/new file.swift"])
        self.assertEqual(code, 0)
        self.assertEqual(report["files"], ["Sources/new file.swift"])
        self.assertIn("+let added = true", report["diff_preview"])
        api.assert_not_called()

    def test_sensitive_paths_are_excluded_even_if_tracked(self):
        self.write(".env", "PRIVATE_SETTING=old\n")
        self.write(".claude/settings.local.json", '{"private": "old"}\n')
        self.git("add", "-f", ".env", ".claude/settings.local.json")
        self.git("commit", "-qm", "tracked settings fixture")
        self.write(".env", "PRIVATE_SETTING=new\n")
        self.write(".claude/settings.local.json", '{"private": "new"}\n')
        code, report, api = self.run_check()
        self.assertEqual(code, 0)
        self.assertEqual(set(report["excluded_files"]), {".env", ".claude/settings.local.json"})
        self.assertNotIn("PRIVATE_SETTING", report["diff_preview"])
        self.assertNotIn('private', report["diff_preview"])
        api.assert_not_called()

    def test_off_blocks_send_but_allows_local_preview(self):
        self.home.joinpath("state").write_text("off\n", encoding="utf-8")
        code, report, api = self.run_check(["--send"])
        self.assertEqual((code, report["reason"]), (2, "disabled"))
        api.assert_not_called()
        code, report, api = self.run_check()
        self.assertEqual((code, report["status"]), (0, "preview"))
        api.assert_not_called()

    def test_sensitive_default_skip_and_explicit_redact(self):
        self.write("Sources/Reminder.swift", 'password = "not for outside"\n')
        def redactor(text):
            return text.replace("not for outside", "[REDACTED]"), {"credentials": 1}
        code, report, api = self.run_check(["--send"], redactor=redactor)
        self.assertEqual((code, report["reason"]), (2, "sensitive_data_detected"))
        api.assert_not_called()
        code, report, api = self.run_check(redactor=redactor)
        self.assertNotIn("not for outside", report["diff_preview"])
        self.assertIn("[REDACTED]", report["diff_preview"])
        self.config["sensitive_handling"] = "redact"
        code, report, api = self.run_check(["--send"], redactor=redactor)
        self.assertEqual((code, report["status"]), (0, "completed"))
        self.assertNotIn("not for outside", api.call_args.args[1]["diff"])

    def test_shared_redactor_catches_short_and_multiword_credentials(self):
        self.write("Sources/Reminder.swift", 'password = "a b"\napi_key = "xy"\n')
        code, report, api = self.run_check(["--send"])
        self.assertEqual((code, report["reason"]), (2, "sensitive_data_detected"))
        self.assertGreaterEqual(sum(report["redactions"].values()), 2)
        api.assert_not_called()
        code, report, api = self.run_check()
        self.assertNotIn('"a b"', report["diff_preview"])
        self.assertNotIn('"xy"', report["diff_preview"])

    def test_untracked_symlinks_are_not_followed(self):
        self.write("outside-data.txt", "do not follow this file\n")
        self.repo.joinpath("alias.swift").symlink_to(self.repo / "outside-data.txt")
        code, report, api = self.run_check(["--include-untracked", "--", "alias.swift"])
        self.assertEqual((code, report["reason"]), (2, "unsupported_file"))
        self.assertNotIn("do not follow", json.dumps(report))
        api.assert_not_called()

    def test_oversized_diff_is_refused_not_truncated(self):
        self.config["max_diff_chars"] = 400
        self.write("Sources/Reminder.swift", "x" * 2000 + "\n")
        code, report, api = self.run_check(["--send"])
        self.assertEqual(code, 2)
        self.assertIn(report["reason"], {"git_output_limit", "diff_too_large"})
        self.assertNotEqual(report["status"], "completed")
        api.assert_not_called()

    def test_bad_revision_and_git_flags_are_errors(self):
        for arguments in (["missing-branch"], ["--no-index"], ["HEAD", "--", "../outside"]):
            with self.subTest(arguments=arguments):
                code, report, api = self.run_check(arguments)
                self.assertEqual(code, 2)
                self.assertEqual(report["status"], "error")
                api.assert_not_called()

    def test_revision_range_does_not_include_later_working_changes(self):
        self.git("add", "Sources/Reminder.swift")
        self.git("commit", "-qm", "second")
        self.write("Sources/Reminder.swift", "let value = 999\n")
        code, report, api = self.run_check(["HEAD~1", "HEAD", "--", "Sources/Reminder.swift"])
        self.assertEqual(code, 0)
        self.assertIn("+let value = 2", report["diff_preview"])
        self.assertNotIn("999", report["diff_preview"])
        api.assert_not_called()

    def test_external_diff_is_disabled(self):
        marker = self.repo / "external-was-run"
        external = self.repo / "external diff.sh"
        external.write_text("#!/bin/sh\ntouch '" + str(marker) + "'\n", encoding="utf-8")
        external.chmod(0o700)
        self.git("config", "diff.external", str(external))
        code, report, api = self.run_check()
        self.assertEqual(code, 0)
        self.assertFalse(marker.exists())
        self.assertIn("+let value = 2", report["diff_preview"])

    def test_unborn_repository_preserves_staged_and_unstaged_changes(self):
        fresh = self.repo / "new repository"
        fresh.mkdir()
        home = fresh / ".claude" / "jev"
        home.mkdir(parents=True)
        subprocess.run(["git", "init", "-q"], cwd=fresh, check=True)
        source = fresh / "new.swift"
        source.write_text("let staged = 1\n", encoding="utf-8")
        subprocess.run(["git", "add", "new.swift"], cwd=fresh, check=True)
        source.write_text("let staged = 2\n", encoding="utf-8")
        options = check.parse_arguments([])
        diff, metadata = check.collect_diff(home, options, self.config)
        self.assertIn("+let staged = 1", diff)
        self.assertIn("+let staged = 2", diff)
        self.assertEqual(metadata["files"], ["new.swift"])

    def test_git_timeout_and_output_bounds(self):
        fake_bin = self.repo / "fake bin"
        fake_bin.mkdir()
        fake_git = fake_bin / "git"
        environment = {"PATH": str(fake_bin) + os.pathsep + os.environ.get("PATH", "")}
        behaviours = [
            ("import time\ntime.sleep(10)\n", "git_timeout"),
            ("import os\nos.write(1, b'x' * 65536)\n", "git_output_limit"),
        ]
        for body, reason in behaviours:
            with self.subTest(reason=reason):
                fake_git.write_text("#!" + sys.executable + "\n" + body, encoding="utf-8")
                fake_git.chmod(0o700)
                with mock.patch.dict(os.environ, environment):
                    with self.assertRaises(JevError) as raised:
                        check._git(self.repo, ["status"], 0.15, 1024)
                self.assertEqual(raised.exception.code, reason)

    def test_missing_nonfinite_and_invalid_answers_never_complete(self):
        missing = self.response()
        del missing["answers"]["stale_comment"]
        invalids = [missing]
        for value in (float("nan"), float("inf"), -0.1, 1.1, True, "0.8"):
            answer = self.response()
            answer["answers"]["stale_comment"]["noul"] = value
            invalids.append(answer)
        for answer in invalids:
            with self.subTest(answer=repr(answer)):
                code, report, api = self.run_check(["--send"], response=answer)
                self.assertEqual((code, report["status"]), (2, "error"))
                self.assertEqual(report["reason"], "invalid_response")

    def test_network_error_does_not_claim_completion(self):
        code, report, api = self.run_check(["--send"], error=JevError("http_error", "Request failed."))
        self.assertEqual((code, report["reason"]), (2, "http_error"))
        api.assert_called_once()

    def test_high_score_is_advisory_unless_ci_gate_is_requested(self):
        code, report, api = self.run_check(["--send"], response=self.response(0.9))
        self.assertEqual(code, 0)
        self.assertTrue(report["problem_flagged"])
        self.assertFalse(report["tests_run"])
        code, report, api = self.run_check(["--send", "--fail-on-problem"], response=self.response(0.9))
        self.assertEqual(code, 3)
        self.assertEqual(report["status"], "completed")

    def test_switch_off_during_collection_prevents_send(self):
        with mock.patch.object(check, "is_enabled", side_effect=[True, False]):
            code, report, api = self.run_check(["--send"])
        self.assertEqual((code, report["reason"]), (2, "disabled"))
        api.assert_not_called()

    def test_no_changes_does_not_fall_back_to_an_unrequested_old_commit(self):
        self.git("checkout", "--", "Sources/Reminder.swift")
        code, report, api = self.run_check(["--send"])
        self.assertEqual((code, report["reason"]), (2, "no_eligible_changes"))
        api.assert_not_called()


if __name__ == "__main__":
    unittest.main()
