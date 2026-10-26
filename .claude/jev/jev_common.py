#!/usr/bin/env python3
"""Shared, standard-library-only boundaries for Jev hooks. Python 3.9+."""

import datetime as dt
import hashlib
import json
import math
import os
from pathlib import Path
import re
import stat
import subprocess
import tempfile
import urllib.error
import urllib.request

HERE = Path(__file__).resolve().parent
TOOL_VERSION = "2.0.0"
API_ENDPOINT = "https://api.typesafe.ai/v1/systemone"
# macOS Keychain item holding the TypeSafe key, so it never sits in a settings file
# that Claude Code injects into every subprocess and may echo into transcripts.
KEYCHAIN_SERVICE = "typesafe-jev-api-key"
MAX_JSON_BYTES = 1_048_576
TIERS = ("haiku", "sonnet", "opus")
DEFAULT_CONFIG = {
    "schema_version": 2,
    "jev_model": "jev-1.13.0",
    "main_tier": None,
    "auto_load_skills": [],
    "sensitive_handling": "skip",
    "max_prompt_chars": 20000,
    "max_diff_chars": 60000,
    "request_timeout_seconds": 12,
    "git_timeout_seconds": 15,
    "model_tracking_max_age_seconds": 86400,
    "log_retention_days": 7,
    "exclude_globs": [
        ".env", ".env.*", "*.pem", "*.key", "*.p12", "*.pfx", "*.keystore",
        "id_rsa*", "id_ed25519*", "credentials*", "*secret*", ".npmrc", ".pypirc",
        ".netrc", ".git/**", ".aws/**", ".ssh/**", ".kube/**",
        ".claude/settings*.json", ".claude/jev/state", ".claude/jev/config.json",
        ".claude/jev/last-decision.json", ".claude/jev/.runtime/**",
    ],
}


class JevError(Exception):
    """Only a short, local error code crosses the API/log boundary."""

    def __init__(self, code, detail=""):
        self.code = code if isinstance(code, str) and re.fullmatch(r"[a-z0-9_]{1,64}", code) else "internal_error"
        # External exception text and HTTP bodies must never enter this field.
        self.detail = detail if isinstance(detail, str) and re.fullmatch(r"[a-zA-Z0-9_ .:-]{0,120}", detail) else ""
        super().__init__(self.code)


def _no_constant(_value):
    raise ValueError("Non-finite JSON")


def _finite_float(value):
    result = float(value)
    if not math.isfinite(result):
        raise ValueError("Non-finite JSON")
    return result


def _no_duplicate_pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Duplicate JSON key")
        result[key] = value
    return result


def parse_json(raw):
    return json.loads(raw, parse_constant=_no_constant, parse_float=_finite_float, object_pairs_hook=_no_duplicate_pairs)


def _checked_path(path):
    path = Path(os.path.abspath(os.fspath(path)))
    # Refuse symlinked parents too; writes must stay within the chosen directory.
    for part in reversed((path,) + tuple(path.parents)):
        try:
            info = part.lstat()
        except FileNotFoundError:
            continue
        if stat.S_ISLNK(info.st_mode):
            raise JevError("unsafe_path")
    return path


def _read_json(path, max_bytes=MAX_JSON_BYTES):
    path = _checked_path(path)
    if not path.is_file():
        raise OSError("Missing regular file")
    with path.open("rb") as handle:
        raw = handle.read(max_bytes + 1)
    if len(raw) > max_bytes:
        raise JevError("file_too_large")
    return parse_json(raw.decode("utf-8"))


def load_config(home=HERE):
    result = dict(DEFAULT_CONFIG)
    result["exclude_globs"] = list(DEFAULT_CONFIG["exclude_globs"])
    result["auto_load_skills"] = []
    path = Path(home) / "config.json"
    try:
        if path.exists() or path.is_symlink():
            values = _read_json(path, 65536)
            if not isinstance(values, dict) or set(values) - set(result):
                raise ValueError("Unknown config fields")
            result.update(values)
        if type(result["schema_version"]) is not int or result["schema_version"] != 2:
            raise ValueError("Wrong config schema")
        if not isinstance(result["jev_model"], str) or not re.fullmatch(r"jev-[a-zA-Z0-9.-]{1,64}", result["jev_model"]):
            raise ValueError("Invalid model")
        if result["main_tier"] not in (None,) + TIERS:
            raise ValueError("Invalid main tier")
        if result["sensitive_handling"] not in ("skip", "redact"):
            raise ValueError("Invalid privacy mode")
        bounds = {
            "max_prompt_chars": (1, 100000), "max_diff_chars": (1, 500000),
            "request_timeout_seconds": (1, 60), "git_timeout_seconds": (1, 120),
            "model_tracking_max_age_seconds": (1, 86400), "log_retention_days": (1, 90),
        }
        for key, (minimum, maximum) in bounds.items():
            value = result[key]
            if type(value) is not int or not minimum <= value <= maximum:
                raise ValueError("Invalid bound")
        for key in ("auto_load_skills", "exclude_globs"):
            values = result[key]
            if not isinstance(values, list) or len(values) > 255 or any(not isinstance(v, str) or not v or len(v) > 300 or any(ord(c) < 32 for c in v) for v in values):
                raise ValueError("Invalid list")
        if any(not re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9_.:-]{0,159}", v) for v in result["auto_load_skills"]):
            raise ValueError("Invalid skill name")
    except (OSError, ValueError, TypeError, JevError) as exc:
        raise JevError("invalid_config") from exc
    return result


def is_enabled(home=HERE):
    try:
        path = _checked_path(Path(home) / "state")
        if not path.is_file():
            return False
        with path.open(encoding="utf-8") as handle:
            raw = handle.read(65)
            return len(raw) <= 64 and raw.strip() == "on"
    except (OSError, UnicodeError, JevError):
        return False


def read_api_key():
    """Return the TypeSafe key from TYPESAFE_API_KEY, else the macOS Keychain, else ""."""
    value = os.environ.get("TYPESAFE_API_KEY", "")
    if not value.strip():
        try:
            found = subprocess.run(
                ["security", "find-generic-password", "-s", KEYCHAIN_SERVICE, "-w"],
                capture_output=True, text=True, timeout=10, check=False,
            )
        except (OSError, subprocess.SubprocessError):
            return ""
        value = found.stdout if found.returncode == 0 else ""
    if not isinstance(value, str):
        return ""
    value = value.strip()
    if not value or len(value) > 4096 or any(ord(c) < 33 or ord(c) > 126 for c in value):
        return ""
    return value


# These recognizers reduce accidental disclosure; they cannot prove text is safe.
_ASSIGNMENT = re.compile(
    r'''(?ix)(?P<prefix>["']?(?:[a-z0-9_-]*_)?(?:password|passwd|pwd|api[_-]?key|access[_-]?token|refresh[_-]?token|auth[_-]?token|client[_-]?secret|secret[_-]?access[_-]?key|secret[_-]?key|private[_-]?key|token|secret)["']?\s*[:=]\s*)(?P<value>"(?:\\.|[^"\\\r\n])*"|'(?:\\.|[^'\\\r\n])*'|[^\s,;\}\]\r\n]+)'''
)
_NAMED_PRIVATE = re.compile(
    r'''(?ix)(?P<prefix>["']?(?:ssn|social[_ -]?security|passport(?:[_ -]?(?:number|no))?|national[_ -]?id|credit[_ -]?card(?:[_ -]?number)?)["']?\s*[:=]\s*)(?P<value>"(?:\\.|[^"\\\r\n])*"|'(?:\\.|[^'\\\r\n])*'|[^\s,;\}\]\r\n]+)'''
)
_PATTERNS = (
    ("private_key", re.compile(r"-----BEGIN (?:[A-Z ]+ )?PRIVATE KEY-----[\s\S]*?(?:-----END (?:[A-Z ]+ )?PRIVATE KEY-----|\Z)")),
    ("bearer", re.compile(r"(?i)\bBearer[ \t]+[A-Za-z0-9._~+/=-]{4,}")),
    ("vendor_key", re.compile(r"\b(?:sk-(?:ant-|proj-)?[A-Za-z0-9_-]{12,}|gh[pousr]_[A-Za-z0-9_]{12,}|github_pat_[A-Za-z0-9_]{12,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{12,})\b")),
    ("url_credential", re.compile(r"(?i)\b(?:https?|postgres(?:ql)?|mysql|redis|mongodb(?:\+srv)?)://[^\s/@:]+:[^\s/@]+@")),
    ("email", re.compile(r"(?<![\w.+-])[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+")),
)


def redact_sensitive(text):
    if not isinstance(text, str):
        raise JevError("invalid_input")
    counts = {}

    def assignment(match, category):
        value = match.group("value")
        bare = value.strip("\"'")
        quoted = value.startswith(("\"", "'"))
        # Empty literals, our markers, and clear environment lookups are not secrets.
        marker = re.fullmatch(r"\[REDACTED(?:_[A-Z_]+)?\]", bare)
        expression = not quoted and (bare.lower() in ("none", "null", "true", "false") or re.match(r"(?:os\.environ|os\.getenv|process\.env|environ\[|getenv\(|\$\{|\$[A-Z_])", bare))
        if not bare or marker or expression:
            return match.group(0)
        counts[category] = counts.get(category, 0) + 1
        return match.group("prefix") + '"[REDACTED]"'

    for category, pattern in _PATTERNS:
        def replace(_match, category=category):
            counts[category] = counts.get(category, 0) + 1
            return "[REDACTED_" + category.upper() + "]"
        text = pattern.sub(replace, text)
    text = _ASSIGNMENT.sub(lambda m: assignment(m, "credential"), text)
    text = _NAMED_PRIVATE.sub(lambda m: assignment(m, "private_identifier"), text)
    return text, counts


def _clean_outbound(value, mode):
    """Inspect every outbound string, including catalog descriptions and keys."""
    if isinstance(value, str):
        clean, counts = redact_sensitive(value)
        if counts and mode == "skip":
            raise JevError("sensitive_content")
        return clean
    if isinstance(value, list):
        return [_clean_outbound(v, mode) for v in value]
    if isinstance(value, dict):
        result = {}
        for key, item in value.items():
            if not isinstance(key, str):
                raise JevError("invalid_input")
            # Keys identify response options, so never silently change a key.
            _clean_outbound(key, "skip")
            if type(item) in (str, int, float) and (_ASSIGNMENT.match(key + '=\"x\"') or _NAMED_PRIVATE.match(key + '=\"x\"')):
                _, counts = redact_sensitive(key + "=" + json.dumps(item))
                if counts:
                    if mode == "skip":
                        raise JevError("sensitive_content")
                    result[key] = "[REDACTED]"
                    continue
            result[key] = _clean_outbound(item, mode)
        return result
    if value is None or type(value) in (int, bool):
        return value
    if type(value) is float and math.isfinite(value):
        return value
    raise JevError("invalid_input")


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise JevError("redirect_refused")


def call_jev(api_key, state, questions, config):
    if not api_key:
        raise JevError("missing_api_key")
    body = _clean_outbound({"model": config["jev_model"], "state": state, "questions": questions}, config["sensitive_handling"])
    try:
        data = json.dumps(body, ensure_ascii=False, allow_nan=False).encode("utf-8")
        if len(data) > MAX_JSON_BYTES:
            raise JevError("request_too_large")
        request = urllib.request.Request(API_ENDPOINT, data=data, headers={"Authorization": "Bearer " + api_key, "Content-Type": "application/json"}, method="POST")
        opener = urllib.request.build_opener(_NoRedirect())
        with opener.open(request, timeout=config["request_timeout_seconds"]) as response:
            raw = response.read(MAX_JSON_BYTES + 1)
        if len(raw) > MAX_JSON_BYTES:
            raise JevError("response_too_large")
        result = parse_json(raw.decode("utf-8"))
        if not isinstance(result, dict) or not isinstance(result.get("answers"), dict):
            raise JevError("invalid_response")
        return result
    except JevError:
        raise
    except urllib.error.HTTPError as exc:
        code = "http_" + str(exc.code) if type(exc.code) is int else "http_error"
        exc.close()
        raise JevError(code) from None
    except (urllib.error.URLError, OSError, TimeoutError):
        raise JevError("network_error") from None
    except (ValueError, UnicodeError, TypeError, RecursionError):
        raise JevError("invalid_response") from None


def _probability(value):
    if type(value) not in (int, float) or not 0 <= value <= 1 or not math.isfinite(value):
        raise JevError("invalid_response")
    return float(value)


def validate_choice(answer, options):
    names = tuple(options)
    if not names or len(names) != len(set(names)) or not isinstance(answer, dict) or answer.get("type") != "choice":
        raise JevError("invalid_response")
    choice = answer.get("choice")
    probabilities = answer.get("probabilities")
    if not isinstance(choice, str) or choice not in names or not isinstance(probabilities, dict) or set(probabilities) != set(names):
        raise JevError("invalid_response")
    probs = {name: _probability(probabilities[name]) for name in names}
    confidence = _probability(answer.get("confidence"))
    if abs(sum(probs.values()) - 1.0) > 0.02 or probs[choice] + 1e-8 < max(probs.values()):
        raise JevError("invalid_response")
    expected = (max(probs.values()) - 1 / len(names)) / (1 - 1 / len(names)) if len(names) > 1 else 1.0
    # Tolerate small display/rounding differences, not contradictory confidence.
    if abs(confidence - expected) > 0.03:
        raise JevError("invalid_response")
    return {"type": "choice", "choice": choice, "confidence": confidence, "probabilities": probs}


def validate_noul(answer):
    if not isinstance(answer, dict) or answer.get("type") != "noul":
        raise JevError("invalid_response")
    return _probability(answer.get("noul"))


def atomic_write_text(path, text, mode=0o600):
    path = _checked_path(path)
    missing = []
    parent = path.parent
    while not parent.exists():
        missing.append(parent)
        parent = parent.parent
    for directory in reversed(missing):
        directory.mkdir(mode=0o700, exist_ok=True)
    _checked_path(path)
    temporary = None
    try:
        descriptor, temporary = tempfile.mkstemp(prefix=".jev-write-", dir=str(path.parent))
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            os.fchmod(handle.fileno(), mode)
            handle.write(text)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        if temporary and os.path.exists(temporary):
            os.unlink(temporary)


def atomic_write_json(path, data):
    atomic_write_text(path, json.dumps(data, ensure_ascii=False, allow_nan=False, indent=2) + "\n")


def utc_now():
    return dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def session_key(session_id):
    text = session_id if isinstance(session_id, str) and session_id else "unknown-session"
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:24]


def _model_name(value):
    if isinstance(value, dict):
        for key in ("id", "model", "name", "display_name"):
            if isinstance(value.get(key), str) and value[key].strip():
                return value[key].strip()[:160]
        return ""
    return value.strip()[:160] if isinstance(value, str) else ""


def model_tier(value):
    name = _model_name(value).lower()
    # Anchored families: 'not-opus' and arbitrary strings containing a tier fail.
    match = re.fullmatch(r"(?:claude[- ](?:\d+(?:[.-]\d+)*[- ])?)?(opus|sonnet|haiku)(?:[- ]\d+(?:[. -]\d+)*(?:-[a-z0-9]+)?)?(?:\[1m\])?", name)
    return match.group(1) if match else None


def remember_main_model(home, session_id, model, source="hook"):
    if not isinstance(session_id, str) or not session_id:
        return
    name = _model_name(model)
    source = source if source in ("hook", "SessionStart", "PostModelSwitch", "statusline", "payload") else "hook"
    record = {"timestamp": utc_now(), "tier": model_tier(model), "source": source}
    # Unknown names need only invalidate the old tier; do not persist arbitrary text.
    if record["tier"] is not None:
        record["model"] = name
    atomic_write_json(Path(home) / ".runtime" / "models" / (session_key(session_id) + ".json"), record)


def _fresh(timestamp, max_age):
    if not isinstance(timestamp, str):
        return False
    try:
        when = dt.datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
        age = (dt.datetime.now(dt.timezone.utc) - when).total_seconds()
        return 0 <= age <= max_age
    except (ValueError, TypeError, OverflowError):
        return False


def resolve_main_tier(payload, config, home=HERE):
    for key in ("model", "current_model", "active_model"):
        if key in payload and payload[key] is not None:
            return model_tier(payload[key]), "payload"
    session_id = payload.get("session_id")
    if isinstance(session_id, str) and session_id:
        try:
            capabilities = _read_json(Path(home) / ".runtime" / "installation.json", 8192)
            supported = isinstance(capabilities, dict) and (capabilities.get("post_model_switch") is True or capabilities.get("own_statusline") is True)
            record = _read_json(Path(home) / ".runtime" / "models" / (session_key(session_id) + ".json"), 8192)
            if supported and isinstance(record, dict) and _fresh(record.get("timestamp"), config["model_tracking_max_age_seconds"]):
                tier = record.get("tier")
                if tier not in TIERS:
                    return None, "tracked_unknown"
                return tier, "session_tracking"
        except (OSError, ValueError, UnicodeError, JevError):
            pass
    tier = config.get("main_tier")
    return (tier, "explicit_config") if tier in TIERS else (None, "unknown")


def _prune_runtime(home, days):
    cutoff = dt.datetime.now(dt.timezone.utc).timestamp() - days * 86400
    seen = 0
    for folder in ("models", "decisions", "observations"):
        root = _checked_path(Path(home) / ".runtime" / folder)
        if not root.is_dir():
            continue
        with os.scandir(root) as entries:
            for entry in entries:
                seen += 1
                if seen > 512:
                    return
                if re.fullmatch(r"[a-f0-9]{24}\.json", entry.name) and entry.is_file(follow_symlinks=False) and entry.stat(follow_symlinks=False).st_mtime < cutoff:
                    os.unlink(entry.path)


def record_event(home, session_id, record):
    # A second allowlist prevents accidental prompt/diff logging by callers.
    allowed = {"status", "reason", "action", "recommended_model", "selected_model", "main_tier", "main_model_source", "skill", "answers", "jev_model", "usage", "input_chars", "redactions"}
    event = {k: v for k, v in record.items() if k in allowed}
    event.update({"tool_version": TOOL_VERSION, "timestamp": utc_now(), "session": session_key(session_id)})
    atomic_write_json(Path(home) / ".runtime" / "decisions" / (session_key(session_id) + ".json"), event)
    atomic_write_json(Path(home) / "last-decision.json", event)
    try:
        _prune_runtime(home, load_config(home)["log_retention_days"])
    except (OSError, ValueError, JevError):
        pass


def read_decision(home, session_id=None):
    path = Path(home) / (".runtime/decisions/" + session_key(session_id) + ".json") if session_id else Path(home) / "last-decision.json"
    try:
        result = _read_json(path, 131072)
        if not isinstance(result, dict) or result.get("tool_version") != TOOL_VERSION:
            return {}
        return result
    except (OSError, ValueError, UnicodeError, JevError):
        return {}


def safe_terminal_text(text):
    value = str(text) if text is not None else ""
    value = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", value)
    return "".join(c for c in value if c.isprintable() and c not in "\u202a\u202b\u202c\u202d\u202e\u2066\u2067\u2068\u2069")[:160]
