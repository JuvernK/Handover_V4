# CLAUDE.md

Compatibility guidance for Claude Code.

The canonical repository instructions live in `AGENTS.md`. Read that file
before working in this repository.

- Never use em dash "--". Use plain dash instead. When writting commit message, NEVER auto add your agent name as co author. When making technical decisions, do not give much weight to development cost. Instead, prefer quality, simplicity, robustness, scalability and long term maintainability. When doing bug fixes, always start with reproducing the bug in an E2E setting as closely aligned with how an end user will use it. This make sure you find the real problem so your fix is actually solve it. When end-to-end testing a product, be picky about the UI you see and be obsessed with pixel perfection. If something clearly looks off, even if it is not directly related to what you are doing, try to get it fixed along.

## Documentation sources

- `AGENTS.md` — canonical working, build, and verification instructions.
- `CONTEXT.md` — canonical project-specific domain language.
- `PROJECT_OVERVIEW.md` — current implementation and folder map.
- `docs/adr/` — durable architectural decisions and their rationale.

Do not duplicate these sources here. Follow the references in `AGENTS.md` for
issue tracking, triage, and domain-documentation conventions.
