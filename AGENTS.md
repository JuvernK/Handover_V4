# Handover V4

## Agreed product direction

- Build the native SwiftUI dashboard first; immersive integration is a later step.
- Use five collapsible ISBAR sections, navigation shortcuts, and persistent vitals on wide windows.
- Patient cases come from `Handover_V4/Data/PatientData.json`. The standalone HTML is a visual reference only.
- Select the case manually with `AppModel(initialBedNumber:)`. Do not add a patient picker unless requested.
- Keep clinical records in `Patient`; keep ISBAR focus and disclosure in dashboard presentation state.
- Preserve existing SharePlay messages and authored spatial point-of-interest names.

## Working in this repository

- Never use em dash "--". Use plain dash instead. 
- When writting commit message, NEVER auto add your agent name as co author. 
- When making technical decisions, do not give much weight to development cost. Instead, prefer quality, simplicity, robustness, scalability and long term maintainability. 
- When doing bug fixes, always start with reproducing the bug in an E2E setting as closely aligned with how an end user will use it. This make sure you find the real problem so your fix is actually solve it. When end-to-end testing a product, be picky about the UI you see and be obsessed with pixel perfection. If something clearly looks off, even if it is not directly related to what you are doing, try to get it fixed along
- Use `docs/dashboard-design.md` for the current implementation scope and validation notes.
- Verify presentation-state transitions and build the visionOS application after relevant Swift changes.

## Multiple agents and worktrees

- There is other AI agent working on the other worktree

## Documentation

- At the top the swift file, briefly shows the flow in arrow about how it will interact with other file.
- Document the purpose, ownership, and meaningful behavior of new modules and public-facing methods with concise Swift documentation comments.
- Explain why a rule exists; avoid comments that merely repeat the code.
- Delete unused functions and comments. Keep the workspace tidy
- Update `docs/dashboard-design.md` when presentation behavior, file responsibilities, or validation commands change.
- Keep implementation status separate from future plans, and identify checks that have not been performed.
- Documentation-only changes do not require rebuilding the app; check links, commands, and consistency against the code.
