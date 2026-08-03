# CLAUDE.md

Compatibility guidance for Claude Code.

The canonical repository instructions live in `AGENTS.md`. Read that file
before working in this repository; it preserves the complete project, build,
architecture, testing-status, and visionOS guidance previously recorded here.

## Claude Code checklist

- Read `PROJECT_OVERVIEW.md` before changing architecture.
- Use the visionOS build command documented in `AGENTS.md`. Prefer Xcode and the
  Apple Vision Pro simulator for interactive verification because
  `xcodebuild -list` and simulator commands can be slow or hang.
- The repository currently has no test target. Do not report automated test
  coverage that does not exist.
- Preserve the separation between owned state and SharePlay transport. A
  synchronized value requires state ownership, message handling, local
  broadcast, remote application, and late-join catch-up.
- Read `docs/agents/` for tracker, triage, and domain conventions. Use
  `CONTEXT.md` terminology and respect relevant records under `docs/adr/`.
