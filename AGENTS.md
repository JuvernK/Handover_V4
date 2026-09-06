# Handover V4

## visionOS development guidelines

Apple's official references for spatial UI work on this project:

- **Human Interface Guidelines — Designing for visionOS**
  https://developer.apple.com/design/human-interface-guidelines/designing-for-visionos
  Read this before designing any new window, ornament, or immersive interaction.
- **visionOS developer documentation (SwiftUI, RealityKit, ARKit for visionOS)**
  https://developer.apple.com/documentation/visionos
- **RealityKit framework reference**
  https://developer.apple.com/documentation/realitykit
- **SwiftUI framework reference**
  https://developer.apple.com/documentation/swiftui

When a design decision or bug looks visionOS-specific, check the HIG page above before guessing — spatial interaction rules (hover, gaze, ornaments, immersion styles) often behave differently from iOS/macOS assumptions.

## Agreed product direction

- Build the native SwiftUI dashboard first; immersive integration is a later step.
- Use five collapsible ISBAR sections, navigation shortcuts, and persistent vitals on wide windows.
- Patient cases come from `Handover_V4/Data/PatientData.json`. The standalone HTML is a visual reference only.
- Select the case manually with `AppModel(initialBedNumber:)`. Do not add a patient picker unless requested.
- Keep clinical records in `Patient`; keep ISBAR focus and disclosure in dashboard presentation state.
- Preserve existing SharePlay messages and authored spatial point-of-interest names.

## Branch strategy

- `latest-prototype` is the active development and integration baseline for the new dashboard UI, rather than `main`.
- `main` contains the more complete immersive-space features the user wants to retain, but that implementation is too buggy to use as the development baseline.
- Use `main` as a reference for intended immersive behavior and useful implementation details. Bring those features into the new dashboard work gradually, reviewing and fixing them as needed.
- Do not assume code on `main` is correct or merge it wholesale merely to recover features.
- Always create a fresh task branch from `latest-prototype` before starting a new task. For ongoing work already on a task branch, continue there until that task is finished.
- Each agent works in its assigned worktree and task branch. Do not switch another agent's branch or edit its worktree.
- Integrate completed task branches into `latest-prototype` when the user authorizes the merge. This policy does not by itself authorize merging or pushing.
- After a successful merge, verify that the task branch's changes are included in the integration branch, then delete the merged local task branch.
- Before deletion, confirm the branch has no outstanding work and is not checked out in another active worktree. Coordinate with its owner if it is still in use; never force-delete a branch to bypass these checks.
- Do not delete `main`, `latest-prototype`, remote branches, or another agent's worktree as routine task-branch cleanup.

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

