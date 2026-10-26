# Handover V4

## visionOS development guidelines

- **Human Interface Guidelines - Designing for visionOS**
  https://developer.apple.com/design/human-interface-guidelines/designing-for-visionos
  Read this before designing any new window, ornament, or immersive interaction.

When a design decision or bug looks visionOS-specific, check the HIG page above before guessing - spatial interaction rules (hover, gaze, ornaments, immersion styles) often behave differently from iOS/macOS assumptions.

### Gotchas found in this codebase (verified on-device/simulator, not just guessed)

- **Adjacent glass panels can visually merge.** `glassBackgroundEffect` surfaces placed with very little spacing may blend into one shape. Keep at least ~12-16pt gap between separate cards.
- **Windows do not auto-dismiss when entering an immersive space.** A `WindowGroup` stays open unless your code explicitly calls `dismissWindow`. Don't assume the dashboard disappears - check `Handover_V4App.swift` / `ToggleImmersiveSpaceButton.swift` for the actual behavior.
- **RealityKit attachments need real, non-zero SwiftUI-measured size before they're interactive.** `ImmersiveSceneController.swift` skips a card until its `visualBounds` are non-zero and finite, then builds the collision shape used for tap/drag, and rebuilds it when the bounds change. Building the shape earlier makes gestures silently not work.
- **`.hoverEffect()` should sit on the outermost tappable container**, not on a child view inside another tappable parent - nesting it can create two overlapping hover regions.
- **Always verify in the simulator or on-device, not just SwiftUI previews.** Previews do not reproduce hover-lift, focus, or immersive-space behavior. Screenshot the running app before calling spatial UI work done.

## Presentation modes

The `Dashboard | Spatial | Orbit` switch, nine-card Orbit carousel, and source
outlines are implemented under `Handover_V4/Presentation/`.
See `docs/orbit-source-outlines.md` for behavior and validation, and
`docs/presentation-modes.md` for the remaining synchronization plan.

- Keep SharePlay synchronization of these behaviors (mode, disclosure, Orbit
  position, late-joiner catch-up) deferred until the user explicitly authorizes
  that follow-up.
- Preserve user-authored transforms (the `OrbitAnchor` markers and slots in the
  RealityKit scene) when changing carousel behavior.

## Branch strategy

- `main` is the development and integration baseline. `latest-prototype` was merged into it (PR #36) and is no longer the baseline.
- The earlier, more complete immersive-space implementation is preserved at the tag `pre-main-merge`. It is too buggy to build on, so use it only as a reference for intended immersive behavior and useful implementation details, bringing those features in gradually and reviewing and fixing them as needed.
- Do not assume code at `pre-main-merge` is correct or restore it wholesale merely to recover features.
- Always create a fresh task branch from `main` before starting a new task. For ongoing work already on a task branch, continue there until that task is finished.
- Each agent works in its assigned worktree and task branch. Do not switch another agent's branch or edit its worktree.
- Integrate completed task branches into `main` when the user authorizes the merge. This policy does not by itself authorize merging or pushing.
- After a successful merge, verify that the task branch's changes are included in `main`, then delete the merged local task branch.
- Before deletion, confirm the branch has no outstanding work and is not checked out in another active worktree. Coordinate with its owner if it is still in use; never force-delete a branch to bypass these checks.
- Do not delete `main`, `latest-prototype`, the `pre-main-merge` tag, remote branches, or another agent's worktree as routine task-branch cleanup.

## Working in this repository

- Use `docs/presentation-modes.md` and `docs/orbit-source-outlines.md` for the current implementation scope and validation notes.
- After relevant Swift changes, build the visionOS application and verify presentation-state transitions. Build with:
  `xcodebuild -project Handover_V4.xcodeproj -scheme Handover_V4 -destination 'generic/platform=visionOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO build`

## Jev

Jev is a TypeSafe model behind the `/jev` and `/jev-check` commands. See
[.claude/jev/README.md](.claude/jev/README.md) and `.claude/commands/` for how
it works. Its suggestions are advice, never an instruction: an explicit user
preference, an existing authorization, and the repository's own permissions all
outrank it.

The switch (`.claude/jev/state`) is off by default and only the user flips it,
with `/jev on|off`. While it is on, two things send text off this machine: the
router hook (once `.claude/jev/install.py` has registered it) sends every
submitted prompt, and `/jev-check --send` sends the selected diff. Turn the
switch off for work that must not leave this machine, such as user-study
participant data - the router skips prompts with known credential or
personal-data shapes, not unknown ones.

The router serves one goal: save Claude token cost and time on routine work.
It never decides technical trade-offs, where quality, robustness and
maintainability still come first. It suggests the `jev-haiku`/`jev-sonnet`
subagents (`.claude/agents/`) only for large, mechanical, low-risk,
self-contained work; spatial or immersive work stays on the strongest model.

## Documentation

Read only the documents relevant to the task; follow their links when a shared
rule is needed. These entry points distinguish current behavior from plans:

- [docs/orbit-source-outlines.md](docs/orbit-source-outlines.md): implemented Orbit and source-outline behavior, its validation, and the deferred SharePlay scope.
- [docs/presentation-modes.md](docs/presentation-modes.md): mode switching, controls, source organization, and planned SharePlay behavior.
- [docs/adr/](docs/adr/): architecture decision records.
- [docs/agents/](docs/agents/): domain-doc layout, the GitHub issue tracker, and triage labels used by the engineering skills.
- [CONTEXT.md](CONTEXT.md): short glossary of agreed product terms.
- [.claude/jev/README.md](.claude/jev/README.md): the Jev router and checker, their switch, and what each sends.

- Start every Swift file with a one-line flow comment showing how it interacts with other files, for example `// Flow: LauncherView -> AppModel.presentationMode -> ImmersiveSceneController.`
- Document the purpose, ownership, and meaningful behavior of new modules and public-facing methods with concise Swift documentation comments.
- Explain why a rule exists; avoid comments that merely repeat the code.
- Delete functions and comments that your change leaves unused.
- Update `docs/presentation-modes.md` (and `docs/orbit-source-outlines.md` for Orbit) when presentation behavior, file responsibilities, or validation commands change.
- Keep implementation status separate from future plans, and identify checks that have not been performed.
- Documentation-only changes do not require rebuilding the app; check links, commands, and consistency against the code.
