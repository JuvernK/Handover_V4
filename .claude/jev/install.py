#!/usr/bin/env python3
"""Install this local package with private backups and conservative merging.

No credentials are requested, no API is contacted, and no permissions are added.
Run with --dry-run first. Close other Claude sessions using the project while
installing, then restart them after the update.
"""

import argparse
import copy
import hashlib
import json
import os
import re
import secrets
import shlex
import stat
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

from jev_common import HERE, TOOL_VERSION, JevError, load_config, safe_terminal_text, utc_now


MIN_POST_MODEL_SWITCH = (2, 1, 251)
MAX_FILE_BYTES = 8 * 1024 * 1024
OWN_HOOK_SCRIPTS = {"route.py", "session.py", "observe.py"}
REQUIRED_FILES = {
    "jev_common.py", "route.py", "check.py", "session.py", "observe.py",
    "statusline.py", "toggle.sh", "install.py", "config.json", "skills.json",
}


class InstallError(Exception):
    def __init__(self, code, backup_path=None):
        self.code = code
        self.backup_path = backup_path
        super().__init__(code)


def checked_path(path):
    path = Path(os.path.abspath(os.path.expanduser(os.fspath(path))))
    for part in reversed([path] + list(path.parents)):
        try:
            info = part.lstat()
        except FileNotFoundError:
            continue
        if stat.S_ISLNK(info.st_mode):
            raise InstallError("symlink_target_refused")
    return path


def read_bytes(path):
    path = checked_path(path)
    try:
        if not path.is_file() or path.stat().st_size > MAX_FILE_BYTES:
            raise InstallError("invalid_or_oversized_file")
        with path.open("rb") as stream:
            data = stream.read(MAX_FILE_BYTES + 1)
        if len(data) > MAX_FILE_BYTES:
            raise InstallError("invalid_or_oversized_file")
        return data
    except OSError as exc:
        raise InstallError("file_read_failed") from exc


def no_constant(_value):
    raise ValueError("Non-finite JSON")


def no_duplicate_pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Duplicate JSON key")
        result[key] = value
    return result


def read_object(path):
    try:
        value = json.loads(
            read_bytes(path).decode("utf-8"), parse_constant=no_constant,
            object_pairs_hook=no_duplicate_pairs,
        )
        if not isinstance(value, dict):
            raise ValueError("Object required")
        return value
    except (ValueError, TypeError, UnicodeError) as exc:
        # Never echo JSON snippets: settings can contain credentials.
        raise InstallError("invalid_json_object") from exc


def json_bytes(value):
    return (json.dumps(value, indent=2, ensure_ascii=False, allow_nan=False) + "\n").encode("utf-8")


def write_bytes(path, data, mode=0o600):
    path = checked_path(path)
    missing = []
    parent = path.parent
    while not parent.exists():
        missing.append(parent)
        parent = parent.parent
    if not parent.is_dir():
        raise InstallError("parent_is_not_directory")
    for directory in reversed(missing):
        directory.mkdir(mode=0o700)
    checked_path(path)
    temporary = None
    try:
        descriptor, temporary = tempfile.mkstemp(prefix=".jev-install-", dir=str(path.parent))
        with os.fdopen(descriptor, "wb") as stream:
            os.fchmod(stream.fileno(), mode)
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        if temporary and os.path.exists(temporary):
            os.unlink(temporary)


def detect_claude_version():
    try:
        result = subprocess.run(
            ["claude", "--version"], capture_output=True, text=True,
            timeout=5, check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if result.returncode:
        return None
    match = re.search(r"(?<!\d)(\d+)\.(\d+)\.(\d+)(?!\d)", result.stdout[:4096])
    return tuple(int(part) for part in match.groups()) if match else None


def owned_script(handler, project):
    """Recognize only direct invocations of scripts in this project's Jev dir."""
    if not isinstance(handler, dict) or handler.get("type") != "command":
        return None
    command = handler.get("command")
    if not isinstance(command, str):
        return None
    arguments = handler.get("args")
    if arguments is not None:
        if not isinstance(arguments, list) or any(not isinstance(arg, str) for arg in arguments):
            return None
        tokens = [command] + arguments
    else:
        try:
            tokens = shlex.split(command)
        except ValueError:
            return None
    if len(tokens) == 1:
        script_path = tokens[0]
    elif len(tokens) >= 2 and re.fullmatch(r"python(?:3(?:\.\d+)?)?", Path(tokens[0]).name):
        remaining = tokens[1:]
        while remaining and remaining[0] in ("-u", "-B", "-I", "-E", "-s"):
            remaining = remaining[1:]
        # These lifecycle hooks take no script arguments. Preserve wrappers,
        # redirects, chained commands, and unfamiliar arguments verbatim.
        if len(remaining) != 1 or remaining[0].startswith("-"):
            return None
        script_path = remaining[0]
    else:
        return None
    for name in OWN_HOOK_SCRIPTS | {"statusline.py"}:
        relative = ".claude/jev/" + name
        accepted = {
            relative, "./" + relative, "$CLAUDE_PROJECT_DIR/" + relative,
            "$" + "{CLAUDE_PROJECT_DIR}/" + relative,
            str(Path(project) / relative),
        }
        if script_path in accepted:
            return name
    return None


def contains_unrecognized_router_hook(settings, project):
    for registrations in settings.get("hooks", {}).values():
        for registration in registrations:
            for handler in registration["hooks"]:
                if not isinstance(handler, dict) or handler.get("type") != "command":
                    continue
                parts = [handler.get("command")]
                arguments = handler.get("args")
                if isinstance(arguments, list):
                    parts.extend(arguments)
                mentions_router = any(
                    isinstance(part, str) and ".claude/jev/route.py" in part
                    for part in parts
                )
                if mentions_router and owned_script(handler, project) != "route.py":
                    return True
    return False


def command_handler(name, timeout):
    return {
        "type": "command",
        "command": 'python3 "$CLAUDE_PROJECT_DIR/.claude/jev/' + name + '"',
        "timeout": timeout,
    }


def merge_settings(settings, project, version, request_timeout):
    result = copy.deepcopy(settings)
    existing_hooks = result.get("hooks", {})
    if not isinstance(existing_hooks, dict):
        raise InstallError("invalid_hooks_configuration")
    hooks = {}
    for event, registrations in existing_hooks.items():
        if not isinstance(registrations, list):
            raise InstallError("invalid_hooks_configuration")
        retained = []
        for registration in registrations:
            if not isinstance(registration, dict) or not isinstance(registration.get("hooks"), list):
                raise InstallError("invalid_hooks_configuration")
            handlers = [
                handler for handler in registration["hooks"]
                if owned_script(handler, project) not in OWN_HOOK_SCRIPTS
            ]
            # An unrelated empty registration is preserved as well.
            if handlers or not registration["hooks"]:
                copied = copy.deepcopy(registration)
                copied["hooks"] = handlers
                retained.append(copied)
        if retained:
            hooks[event] = retained
    hooks.setdefault("UserPromptSubmit", []).append({
        "hooks": [command_handler("route.py", request_timeout + 3)],
    })
    hooks.setdefault("SessionStart", []).append({
        "hooks": [command_handler("session.py", 3)],
    })
    supports_switch = version is not None and version >= MIN_POST_MODEL_SWITCH
    if supports_switch:
        hooks.setdefault("PostModelSwitch", []).append({
            "hooks": [command_handler("session.py", 3)],
        })
    hooks.setdefault("PostToolUse", []).append({
        "matcher": "Agent|Task",
        "hooks": [command_handler("observe.py", 3)],
    })
    result["hooks"] = hooks
    existing_statusline = result.get("statusLine")
    own_statusline = existing_statusline is None or owned_script(existing_statusline, project) == "statusline.py"
    if own_statusline:
        result["statusLine"] = {
            "type": "command",
            # The status-line process has its own payload/environment contract.
            # An absolute shell-quoted path avoids depending on hook-only vars.
            "command": "python3 " + shlex.quote(str(Path(project) / ".claude" / "jev" / "statusline.py")),
        }
    return result, {
        "schema_version": 2,
        "tool_version": TOOL_VERSION,
        "post_model_switch": supports_switch,
        "own_statusline": own_statusline,
        "claude_version": ".".join(str(part) for part in version) if version else None,
    }


def package_files(source):
    source = checked_path(source)
    files = {}
    for path in sorted(source.iterdir()):
        if path.name in ("config.json", "skills.json") or path.suffix in (".py", ".sh", ".md"):
            checked_path(path)
            if not path.is_file():
                raise InstallError("invalid_package_file")
            files[path.name] = read_bytes(path)
    tests = source / "tests"
    if tests.exists() or tests.is_symlink():
        checked_path(tests)
        if not tests.is_dir():
            raise InstallError("invalid_package_tests")
        for path in sorted(tests.rglob("*.py")):
            checked_path(path)
            files[path.relative_to(source).as_posix()] = read_bytes(path)
    if REQUIRED_FILES - set(files):
        raise InstallError("incomplete_package")
    return files


def validate_skills(skills):
    if not isinstance(skills, dict) or not skills or len(skills) > 255:
        raise InstallError("invalid_skill_catalog")
    for name, description in skills.items():
        if not isinstance(name, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.:-]{0,159}", name):
            raise InstallError("invalid_skill_catalog")
        if not isinstance(description, str) or not description.strip() or len(description) > 2000:
            raise InstallError("invalid_skill_catalog")


def default_backup_dir(project):
    digest = hashlib.sha256(str(project).encode("utf-8")).hexdigest()[:16]
    return Path.home() / ".claude" / "jev-backups" / digest


def make_plan(project, source, version):
    project = checked_path(project)
    if not project.is_dir():
        raise InstallError("project_directory_required")
    source = checked_path(source)
    home = project / ".claude" / "jev"
    for directory in (project / ".claude", home, home / ".runtime"):
        checked_path(directory)
        if directory.exists() and not directory.is_dir():
            raise InstallError("installation_directory_conflict")
    files = package_files(source)
    # A user may have a tuned local config. Validate it, retaining its values;
    # absent fields receive this version's defaults through the shared loader.
    try:
        package_config = load_config(source)
        config = load_config(home) if (home / "config.json").exists() else package_config
    except (JevError, OSError, ValueError, TypeError) as exc:
        raise InstallError("invalid_config") from exc
    skill_path = home / "skills.json"
    checked_path(skill_path)
    skills = read_object(skill_path) if skill_path.exists() else read_object(source / "skills.json")
    if "none" not in skills:
        skills["none"] = "No installed skill clearly applies."
    validate_skills(skills)
    settings_path = project / ".claude" / "settings.local.json"
    checked_path(settings_path)
    settings = read_object(settings_path) if settings_path.exists() else {}
    merged_settings, capabilities = merge_settings(
        settings, project, version, config["request_timeout_seconds"]
    )
    files["config.json"] = json_bytes(config)
    files["skills.json"] = json_bytes(skills)
    writes = {home / relative: (data, 0o700 if relative.endswith(".sh") else 0o600)
              for relative, data in files.items()}
    writes[settings_path] = (json_bytes(merged_settings), 0o600)
    writes[home / ".runtime" / "installation.json"] = (json_bytes(capabilities), 0o600)
    state_path = home / "state"
    checked_path(state_path)
    if state_path.exists():
        state_bytes = read_bytes(state_path)
        if state_bytes.strip() not in (b"on", b"off"):
            raise InstallError("invalid_existing_state")
        state = state_bytes.strip().decode("ascii")
    else:
        state = "off"
        writes[state_path] = (b"off\n", 0o600)
    log_path = home / "last-decision.json"
    checked_path(log_path)
    reset_log = not log_path.exists()
    if log_path.exists():
        try:
            previous = read_object(log_path)
            reset_log = (
                previous.get("tool_version") != TOOL_VERSION
                or previous.get("status") not in ("routed", "skipped", "error")
                or any(field in previous for field in ("prompt", "diff", "state", "raw_response"))
            )
        except InstallError as exc:
            if exc.code != "invalid_json_object":
                raise
            reset_log = True
    if reset_log:
        writes[log_path] = (json_bytes({
            "tool_version": TOOL_VERSION,
            "timestamp": utc_now(),
            "status": "skipped",
            "reason": "installed_no_routing_result_yet",
            "action": "main",
        }), 0o600)
    for path in writes:
        checked_path(path)
        if path.exists() and not path.is_file():
            raise InstallError("installation_file_conflict")
    # Save every file that will change, and the shared state for recovery.
    snapshots = {}
    for path in list(writes) + [state_path]:
        if path in snapshots:
            continue
        if path.exists():
            snapshots[path] = (read_bytes(path), stat.S_IMODE(path.stat().st_mode))
        else:
            snapshots[path] = None
    return {
        "project": project, "home": home, "writes": writes,
        "snapshots": snapshots, "state": state, "capabilities": capabilities,
        "legacy_log_reset": reset_log,
        "preserved_router_wrapper": contains_unrecognized_router_hook(merged_settings, project),
    }


def install(project, source=HERE, backup_dir=None, dry_run=False):
    version = detect_claude_version()
    plan = make_plan(project, source, version)
    project = plan["project"]
    backup_root = checked_path(backup_dir or default_backup_dir(project))
    try:
        backup_root.relative_to(project)
    except ValueError:
        pass
    else:
        raise InstallError("backup_must_be_outside_project")
    if backup_root.exists() and not backup_root.is_dir():
        raise InstallError("backup_directory_conflict")
    warnings = []
    if plan["preserved_router_wrapper"]:
        warnings.append(
            "An existing wrapper mentioning .claude/jev/route.py was preserved. "
            "It may duplicate router requests alongside the new direct hook; review that hook."
        )
    if not plan["capabilities"]["post_model_switch"]:
        warnings.append("PostModelSwitch requires verified Claude Code 2.1.251 or later.")
        if not plan["capabilities"]["own_statusline"]:
            warnings.append("Set config.main_tier explicitly; automatic main-model tracking is unavailable.")
    report = {
        "dry_run": bool(dry_run), "file_count": len(plan["writes"]),
        "state": plan["state"], "capabilities": plan["capabilities"],
        "warnings": warnings, "backup_path": None,
    }
    if dry_run:
        return report
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    backup_path = backup_root / (stamp + "-" + secrets.token_hex(4))
    manifest = {
        "tool_version": TOOL_VERSION,
        "project": str(project),
        "created_at": utc_now(),
        "files": {},
    }
    try:
        for path, snapshot in plan["snapshots"].items():
            relative = path.relative_to(project).as_posix()
            manifest["files"][relative] = {
                "existed": snapshot is not None,
                "mode": oct(snapshot[1]) if snapshot is not None else None,
            }
            if snapshot is not None:
                write_bytes(backup_path / relative, snapshot[0], mode=0o600)
        write_bytes(backup_path / "manifest.json", json_bytes(manifest), mode=0o600)
    except (OSError, ValueError, InstallError) as exc:
        raise InstallError("backup_failed_no_project_changes", backup_path=backup_path) from exc
    modified = []
    try:
        # Scripts and metadata are written before registrations. A user should
        # close other sessions while installing so no old hook runs mid-update.
        settings_path = project / ".claude" / "settings.local.json"
        ordered = [path for path in plan["writes"] if path != settings_path] + [settings_path]
        for path in ordered:
            data, mode = plan["writes"][path]
            snapshot = plan["snapshots"][path]
            if snapshot is not None and snapshot == (data, mode):
                continue
            write_bytes(path, data, mode=mode)
            modified.append(path)
    except (OSError, ValueError, InstallError) as exc:
        rollback_failed = False
        for path in reversed(modified):
            snapshot = plan["snapshots"][path]
            try:
                if snapshot is None:
                    checked_path(path).unlink()
                else:
                    write_bytes(path, snapshot[0], mode=snapshot[1])
            except (OSError, ValueError, InstallError):
                rollback_failed = True
        code = "installation_failed_restore_from_backup" if rollback_failed else "installation_failed_files_restored"
        raise InstallError(code, backup_path=backup_path) from exc
    report["backup_path"] = str(backup_path)
    return report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", required=True, help="Existing project directory")
    parser.add_argument("--dry-run", action="store_true", help="Validate and show a plan without changing files")
    parser.add_argument("--backup-dir", help="Private backup root outside the project")
    args = parser.parse_args(argv)
    try:
        report = install(args.project, backup_dir=args.backup_dir, dry_run=args.dry_run)
    except (InstallError, OSError, ValueError) as exc:
        code = exc.code if isinstance(exc, InstallError) else "installation_io_error"
        print("Jev installation stopped: " + code, file=sys.stderr)
        backup_path = getattr(exc, "backup_path", None)
        if backup_path:
            print("Backup: " + safe_terminal_text(str(backup_path)), file=sys.stderr)
        return 2
    label = "Dry run: would update" if report["dry_run"] else "Updated"
    print("%s %d package/configuration files." % (label, report["file_count"]))
    print("Project switch preserved: " + report["state"].upper())
    print("Status line: " + ("Jev status line" if report["capabilities"]["own_statusline"] else "existing status line preserved"))
    for warning in report["warnings"]:
        print("Note: " + warning)
    if report["backup_path"]:
        print("Private backup: " + safe_terminal_text(report["backup_path"]))
        print("Restart Claude Code for this project to load the updated hooks.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
