"""Offline integration tests for model tracking and non-destructive upgrades."""

import copy
import io
import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

PACKAGE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PACKAGE))

import install as installer
import observe
import session
import statusline
from jev_common import (
    DEFAULT_CONFIG, TOOL_VERSION, atomic_write_json, atomic_write_text,
    load_config, remember_main_model, resolve_main_tier, session_key,
)


def files_under(directory):
    return {
        path.relative_to(directory).as_posix(): path.read_bytes()
        for path in Path(directory).rglob("*") if path.is_file() and not path.is_symlink()
    }


class ModelTrackingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="jev-support-")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name).resolve() / "project with spaces" / ".claude" / "jev"
        self.home.mkdir(parents=True)
        atomic_write_text(self.home / "state", "on\n")
        atomic_write_json(self.home / ".runtime" / "installation.json", {
            "schema_version": 2, "post_model_switch": True, "own_statusline": True,
        })

    def test_switch_updates_one_session_and_unknown_family_invalidates_it(self):
        self.assertTrue(session.handle({
            "hook_event_name": "SessionStart", "session_id": "main-one", "model": "opus",
        }, self.home))
        self.assertTrue(session.handle({
            "hook_event_name": "SessionStart", "session_id": "main-two", "model": "sonnet",
        }, self.home))
        self.assertTrue(session.handle({
            "hook_event_name": "PostModelSwitch", "session_id": "main-one",
            "to_model": "haiku", "from_model": "opus",
        }, self.home))
        config = load_config(self.home)
        self.assertEqual(resolve_main_tier({"session_id": "main-one"}, config, self.home)[0], "haiku")
        self.assertEqual(resolve_main_tier({"session_id": "main-two"}, config, self.home)[0], "sonnet")
        self.assertTrue(session.handle({
            "hook_event_name": "PostModelSwitch", "session_id": "main-one",
            "to_model": "unrecognized-gateway-model",
        }, self.home))
        self.assertIsNone(resolve_main_tier({"session_id": "main-one"}, config, self.home)[0])

    def test_wrong_schema_and_worker_events_do_not_replace_main_model(self):
        remember_main_model(self.home, "main", "opus", source="SessionStart")
        model_path = self.home / ".runtime" / "models" / (session_key("main") + ".json")
        before = model_path.read_bytes()
        for payload in ([], None, {"session_id": "main"}, {
            "hook_event_name": "PostModelSwitch", "session_id": "main", "to_model": [],
        }, {
            "hook_event_name": "SessionStart", "session_id": "main", "model": "haiku",
            "agent_id": "worker-id",
        }):
            self.assertFalse(session.handle(payload, self.home))
        with patch.object(statusline, "git_branch", return_value=""):
            rendered = statusline.render({
                "session_id": "main", "task_id": "worker-task", "model": {"id": "haiku"},
                "workspace": {"current_dir": str(self.home)},
            }, self.home)
        self.assertIn("worker payload: haiku", rendered)
        self.assertEqual(model_path.read_bytes(), before)
        self.assertEqual(session.read_payload(io.StringIO("[]")), {})
        self.assertEqual(session.read_payload(io.StringIO("{")), {})

    def test_observer_requires_actual_field_and_keeps_requested_model_separate(self):
        payload = {
            "hook_event_name": "PostToolUse", "session_id": "main", "tool_name": "Agent",
            "tool_use_id": "toolu_123",
            "tool_input": {"model": "haiku", "prompt": "PRIVATE_PROMPT_MUST_NOT_BE_SAVED"},
            "tool_response": {"status": "completed", "model": "haiku"},
        }
        self.assertFalse(observe.handle(payload, self.home))
        observation_dir = self.home / ".runtime" / "observations"
        self.assertFalse(observation_dir.exists())
        payload["tool_response"]["resolvedModel"] = "claude-sonnet-4-6"
        payload["tool_response"]["result"] = "PRIVATE_TOOL_RESULT_MUST_NOT_BE_SAVED"
        self.assertTrue(observe.handle(payload, self.home))
        record = json.loads((observation_dir / (session_key("main") + ".json")).read_text())
        self.assertEqual(record["actual_model"], "claude-sonnet-4-6")
        self.assertEqual(record["observation_scope"], "start")
        self.assertNotIn("PRIVATE_", json.dumps(record))
        self.assertNotIn("haiku", json.dumps(record))
        with patch.object(statusline, "git_branch", return_value=""):
            rendered = statusline.render({
                "session_id": "main", "model": {"id": "opus", "display_name": "Opus"},
                "workspace": {"current_dir": str(self.home)},
            }, self.home)
        self.assertIn("recent worker start: claude-sonnet-4-6", rendered)
        self.assertIn("main: Opus", rendered)
        self.assertNotIn("final", rendered)

    def test_subagent_status_rows_do_not_overwrite_main_agent_session(self):
        remember_main_model(self.home, "main", "opus", source="SessionStart")
        model_path = self.home / ".runtime" / "models" / (session_key("main") + ".json")
        before = model_path.read_bytes()
        with patch.object(statusline, "git_branch", return_value=""):
            for extra in (
                {"tasks": []},
                {"tasks": [{"id": "task-one", "type": "local_agent", "model": "haiku"}]},
                {"id": "task-one", "type": "local_agent", "status": "running"},
            ):
                payload = {"session_id": "main", "model": "haiku", **extra}
                self.assertIn("worker payload:", statusline.render(payload, self.home))
                self.assertEqual(model_path.read_bytes(), before)
            rendered = statusline.render({
                "session_id": "main", "model": {"id": "sonnet"},
                "agent": {"name": "my-main-agent"},
            }, self.home)
        self.assertIn("main: sonnet", rendered)
        self.assertEqual(resolve_main_tier({"session_id": "main"}, load_config(self.home), self.home)[0], "sonnet")

    def test_route_display_distinguishes_advice_and_explains_skip_or_defer(self):
        self.assertEqual(statusline.route_segment({
            "status": "routed", "action": "delegate", "selected_model": "haiku",
        }), "route: suggested haiku")
        for status, action, reason in (
            ("skipped", "main", "missing_api_key"),
            ("error", "main", "invalid_response"),
            ("routed", "defer", "main_model_unknown"),
        ):
            self.assertIn(reason, statusline.route_segment({
                "status": status, "action": action, "reason": reason,
            }))
        rendered = statusline.route_segment({
            "status": "error", "reason": "bad\x1b[2J\n" + "x" * 300,
        })
        self.assertNotIn("\x1b", rendered)
        self.assertNotIn("\n", rendered)
        self.assertLessEqual(len(rendered), 160)

    def test_background_observation_scope_and_terminal_sanitizing(self):
        self.assertTrue(observe.handle({
            "hook_event_name": "PostToolUse", "session_id": "main", "tool_name": "Task",
            "tool_response": {"status": "async_launched", "resolvedModel": "sonnet"},
        }, self.home))
        with patch.object(statusline, "git_branch", return_value="feature\x1b[31mbranch\n"):
            rendered = statusline.render({
                "session_id": "main", "model": {"id": "opus", "display_name": "Opus\x1b[2J"},
                "workspace": {"current_dir": str(self.home)},
            }, self.home)
        self.assertIn("recent worker launch: sonnet", rendered)
        self.assertNotIn("\x1b", rendered)
        self.assertNotIn("\n", rendered)

    def test_toggle_maintains_existing_mod_interface_without_exposing_legacy_log(self):
        for name in ("jev_common.py", "toggle.sh"):
            shutil.copyfile(PACKAGE / name, self.home / name)
        atomic_write_json(self.home / "last-decision.json", {"prompt": "LEGACY_PRIVATE_TEXT"})
        for command, expected in (("off", "OFF"), ("status", "OFF"), ("on", "ON")):
            result = subprocess.run(
                ["bash", str(self.home / "toggle.sh"), command], capture_output=True,
                text=True, check=True, timeout=5,
            )
            self.assertIn(expected, result.stdout)
        self.assertEqual((self.home / "state").read_text(), "on\n")
        self.assertEqual(stat.S_IMODE((self.home / "state").stat().st_mode), 0o600)
        result = subprocess.run(
            ["bash", str(self.home / "toggle.sh"), "last"], capture_output=True,
            text=True, check=True, timeout=5,
        )
        self.assertNotIn("LEGACY_PRIVATE_TEXT", result.stdout)
        atomic_write_json(self.home / "last-decision.json", {
            "tool_version": TOOL_VERSION, "status": "skipped", "reason": "off",
            "session": session_key("main"),
        })
        result = subprocess.run(
            ["bash", str(self.home / "toggle.sh"), "last"], capture_output=True,
            text=True, check=True, timeout=5,
        )
        self.assertEqual(json.loads(result.stdout)["session"], session_key("main"))


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="jev-install-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.project = self.root / "project with spaces"
        self.home = self.project / ".claude" / "jev"
        self.home.mkdir(parents=True)
        self.source = self.root / "release package"
        self.source.mkdir()
        for name in installer.REQUIRED_FILES:
            (self.source / name).write_text("# fixture package\n")
        (self.source / "config.json").write_text(json.dumps(DEFAULT_CONFIG))
        (self.source / "skills.json").write_text(json.dumps({"none": "No skill applies."}))
        (self.source / "README.md").write_text("Local package instructions.\n")
        (self.source / "tests").mkdir()
        (self.source / "tests" / "test_fixture.py").write_text("# offline tests\n")
        self.backups = self.root / "private backups"
        self.settings_path = self.project / ".claude" / "settings.local.json"
        self.settings = {
            "env": {"TYPESAFE_API_KEY": "FAKE_PRIVATE_TEST_KEY"},
            "permissions": {"allow": ["Read"], "deny": ["Bash(rm *)"]},
            "enabledPlugins": {"jev-switch@example": True},
            "statusLine": {"type": "command", "command": "my-existing-statusline"},
            "hooks": {
                "UserPromptSubmit": [{"hooks": [
                    {"type": "command", "command": 'python3 "' + str(self.home / "route.py") + '"'},
                    {"type": "command", "command": "my-existing-mod-hook", "timeout": 7},
                ]}],
                "Stop": [{"hooks": [{"type": "command", "command": "other-workflow"}]}],
            },
        }
        self.settings_path.write_text(json.dumps(self.settings))
        (self.home / "route.py").write_text("# original router\n")
        (self.home / "state").write_text("on\n")
        (self.home / "config.json").write_text(json.dumps({"main_tier": "sonnet", "max_diff_chars": 12345}))
        self.custom_skills = {"none": "My none option.", "my:review": "My custom review workflow."}
        (self.home / "skills.json").write_text(json.dumps(self.custom_skills))
        (self.home / "last-decision.json").write_text(json.dumps({"prompt": "OLD_PRIVATE_PROMPT"}))

    def run_install(self, version=(2, 1, 260), dry_run=False):
        with patch.object(installer, "detect_claude_version", return_value=version):
            return installer.install(self.project, self.source, self.backups, dry_run=dry_run)

    def test_dry_run_changes_nothing_and_does_not_create_backups(self):
        before = files_under(self.project)
        report = self.run_install(dry_run=True)
        self.assertTrue(report["dry_run"])
        self.assertIsNone(report["backup_path"])
        self.assertEqual(files_under(self.project), before)
        self.assertFalse(self.backups.exists())
        self.assertNotIn("FAKE_PRIVATE_TEST_KEY", json.dumps(report))

    def test_upgrade_preserves_mod_permissions_key_state_and_customizations(self):
        original_settings_bytes = self.settings_path.read_bytes()
        report = self.run_install()
        current = json.loads(self.settings_path.read_text())
        for field in ("env", "permissions", "enabledPlugins", "statusLine"):
            self.assertEqual(current[field], self.settings[field])
        self.assertEqual(current["hooks"]["Stop"], self.settings["hooks"]["Stop"])
        self.assertEqual((self.home / "state").read_text(), "on\n")
        self.assertEqual(json.loads((self.home / "skills.json").read_text()), self.custom_skills)
        config = load_config(self.home)
        self.assertEqual(config["main_tier"], "sonnet")
        self.assertEqual(config["max_diff_chars"], 12345)
        self.assertEqual(config["schema_version"], 2)
        self.assertEqual(config["sensitive_handling"], "skip")
        self.assertIn("PostModelSwitch", current["hooks"])
        self.assertTrue((self.home / "tests" / "test_fixture.py").exists())
        log = (self.home / "last-decision.json").read_text()
        self.assertNotIn("OLD_PRIVATE_PROMPT", log)
        self.assertIn("installed_no_routing_result_yet", log)
        backup = Path(report["backup_path"])
        self.assertEqual((backup / ".claude" / "settings.local.json").read_bytes(), original_settings_bytes)
        self.assertEqual(stat.S_IMODE(backup.stat().st_mode), 0o700)
        self.assertEqual(stat.S_IMODE((backup / ".claude" / "settings.local.json").stat().st_mode), 0o600)
        self.assertIn("OLD_PRIVATE_PROMPT", (backup / ".claude" / "jev" / "last-decision.json").read_text())
        self.assertNotIn("FAKE_PRIVATE_TEST_KEY", json.dumps(report))
        first_settings = copy.deepcopy(current)
        self.run_install()
        current = json.loads(self.settings_path.read_text())
        self.assertEqual(current, first_settings)
        own_router_count = sum(
            installer.owned_script(handler, self.project) == "route.py"
            for registration in current["hooks"]["UserPromptSubmit"]
            for handler in registration["hooks"]
        )
        self.assertEqual(own_router_count, 1)
        self.assertIn("my-existing-mod-hook", json.dumps(current["hooks"]))

    def test_old_or_unknown_version_omits_switch_hook_and_disables_unreliable_cache(self):
        (self.home / "config.json").write_text("{}")
        report = self.run_install(version=None)
        settings = json.loads(self.settings_path.read_text())
        self.assertNotIn("PostModelSwitch", settings["hooks"])
        self.assertFalse(report["capabilities"]["post_model_switch"])
        self.assertFalse(report["capabilities"]["own_statusline"])
        remember_main_model(self.home, "main", "opus", source="SessionStart")
        self.assertIsNone(resolve_main_tier({"session_id": "main"}, load_config(self.home), self.home)[0])
        self.assertTrue(report["warnings"])
        settings, capabilities = installer.merge_settings({}, self.project, (2, 1, 250), 12)
        self.assertNotIn("PostModelSwitch", settings["hooks"])
        self.assertTrue(capabilities["own_statusline"])

    def test_compound_router_hooks_are_preserved_and_duplicate_risk_is_reported(self):
        wrappers = [
            {"type": "command", "command": "python3 .claude/jev/route.py && my-mod-hook"},
            {"type": "command", "command": "python3 .claude/jev/route.py > my-route.log"},
            {"type": "command", "command": "python3 .claude/jev/route.py --my-mod-argument"},
        ]
        for handler in wrappers:
            self.assertIsNone(installer.owned_script(handler, self.project))
        self.settings["hooks"]["UserPromptSubmit"][0]["hooks"].extend(wrappers)
        self.settings_path.write_text(json.dumps(self.settings))
        report = self.run_install()
        settings = json.loads(self.settings_path.read_text())
        handlers = [
            handler
            for registration in settings["hooks"]["UserPromptSubmit"]
            for handler in registration["hooks"]
        ]
        for wrapper in wrappers:
            self.assertIn(wrapper, handlers)
        self.assertEqual(sum(
            installer.owned_script(handler, self.project) == "route.py"
            for handler in handlers
        ), 1)
        self.assertTrue(any("duplicate router requests" in warning for warning in report["warnings"]))
        self.assertNotIn("my-mod-hook", json.dumps(report))

    def test_fresh_project_starts_off_and_can_install_own_statusline(self):
        fresh = self.root / "fresh project"
        fresh.mkdir()
        with patch.object(installer, "detect_claude_version", return_value=(2, 1, 251)):
            report = installer.install(fresh, self.source, self.backups)
        settings = json.loads((fresh / ".claude" / "settings.local.json").read_text())
        self.assertEqual((fresh / ".claude" / "jev" / "state").read_text(), "off\n")
        self.assertTrue(report["capabilities"]["own_statusline"])
        self.assertNotIn("permissions", settings)
        self.assertNotIn("env", settings)

    def test_symlink_and_in_project_backup_are_refused_without_mutation(self):
        before = files_under(self.project)
        with patch.object(installer, "detect_claude_version", return_value=(2, 1, 260)):
            with self.assertRaisesRegex(installer.InstallError, "backup_must_be_outside_project"):
                installer.install(self.project, self.source, self.project / "backup")
        self.assertEqual(files_under(self.project), before)
        external = self.root / "external-secret.json"
        external.write_text("PRIVATE_EXTERNAL_FILE")
        self.settings_path.unlink()
        self.settings_path.symlink_to(external)
        with self.assertRaisesRegex(installer.InstallError, "symlink_target_refused"):
            self.run_install()
        self.assertEqual(external.read_text(), "PRIVATE_EXTERNAL_FILE")
        self.assertFalse(self.backups.exists())

    def test_failed_settings_write_rolls_back_files_and_retains_backup(self):
        before = files_under(self.project)
        original_write = installer.write_bytes

        def fail_registration(path, data, mode=0o600):
            if Path(path) == self.settings_path:
                raise OSError("simulated disk write failure")
            return original_write(path, data, mode)

        with patch.object(installer, "write_bytes", side_effect=fail_registration):
            with self.assertRaisesRegex(installer.InstallError, "installation_failed_files_restored") as caught:
                self.run_install()
        self.assertEqual(files_under(self.project), before)
        self.assertTrue(Path(caught.exception.backup_path).is_dir())

    def test_invalid_config_fails_before_backup_or_project_change(self):
        (self.home / "config.json").write_text('{"sensitive_handling": "unknown"}')
        before = files_under(self.project)
        with self.assertRaisesRegex(installer.InstallError, "invalid_config"):
            self.run_install()
        self.assertEqual(files_under(self.project), before)
        self.assertFalse(self.backups.exists())

    def test_oversize_custom_skill_is_rejected_before_installation(self):
        installer.validate_skills({"none": "n" * 2000})
        (self.home / "skills.json").write_text(json.dumps({"none": "n" * 2001}))
        before = files_under(self.project)
        with self.assertRaisesRegex(installer.InstallError, "invalid_skill_catalog"):
            self.run_install()
        self.assertEqual(files_under(self.project), before)
        self.assertFalse(self.backups.exists())


if __name__ == "__main__":
    unittest.main()
