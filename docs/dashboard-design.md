# ISBAR dashboard

## Decision

Patient is the case record. ISBAR is a presentation grouping, not another copy of the case.
The selected bed remains configured in AppModel; runtime patient selection is out of scope.

## Ownership

| Module | Responsibility |
| --- | --- |
| Patient | Authored clinical records |
| HandoverViewModel | Existing case loading and selection |
| DashboardPresentationState | Expanded sections and explicit navigation focus |
| PatientDashboardView | Reusable patient content, navigation and responsive layout |
| DashboardView | Window controls and SharePlay alert |
| ImmersiveView | Existing spatial placement; future dashboard host |

The window and a future immersive host can each own presentation state independently.
Disclosure is local UI state and is not added to SharePlay messages in this iteration.
Existing SectionID card identities remain separate from the five ISBAR groupings.

## File guide

Paths below are relative to the repository root.

| File | Purpose | When to change it |
| --- | --- | --- |
| `Handover_V4/Models/DashboardPresentationState.swift` | Defines the five ISBAR IDs and the rules for opening, closing, focusing, and toggling all sections. Uses Foundation only. | Reading behavior changes. |
| `Handover_V4/View/Dashboard/PatientDashboardView.swift` | Owns reading state, connects section bindings, performs navigation scrolling, and arranges content at wide/narrow sizes. | Layout or view integration changes. |
| `Tests/DashboardPresentationStateChecks.swift` | Runs model transitions without launching the app or a simulator. Lives outside the app folder to avoid a second application entry point. | State rules or regressions need coverage. |
| `AGENTS.md` | Records product constraints, worktree coordination, and documentation expectations for agents. | Working agreements change. |
| `docs/dashboard-design.md` | Explains the design, file responsibilities, current behavior, and verification. | Any documented behavior changes. |

Related files carried forward from the existing UI work:

- `View/Dashboard/DashboardView.swift` supplies the patient and adds window controls and the SharePlay alert.
- `View/Dashboard/ISBARSection.swift` provides section labels, counts, content grouping, disclosure headers, navigation, and the vitals panel. Those paths are under `Handover_V4/`.
- `View/Cards/SituationCard.swift` shows diagnosis, trajectory, acuity, and main concerns.
- `View/Cards/FamilyCard.swift` shows the family contact, bedside presence, and notes.

## How an interaction travels

For example, tapping **A** follows this sequence:

1. The navigation view asks presentation state to focus Assessment.
2. The model opens Assessment and remembers it as the navigation destination, preserving other open sections.
3. PatientDashboardView requests a scroll after yielding to allow layout to update.
4. The one-shot scroll request is cleared so another tap on A can scroll again.

Focus here means the last explicit navigation choice. It is not keyboard focus
and does not track which section happens to be visible during manual scrolling.
Closing the focused section clears focus; opening a header alone does not set it.
The model maintains the rule that a focused section is also expanded.

PatientDashboardView currently owns its state for its SwiftUI view lifetime.
It does not reset disclosure on patient changes or synchronize disclosure between
separate hosts. This matches the current fixed-bed workflow.

## Interaction

- Initially show Situation.
- A navigation shortcut opens and focuses its section without closing other sections.
- Section headers toggle individual sections.
- ALL expands all sections, or collapses them when all are open.
- Wide windows keep the navigation and independently scrollable vitals beside the scrolling sections.
- Narrow windows keep vitals and navigation above the section list in the same scrolling content.
- Counts describe actual records: allergies, main concerns, systems, and urgent tasks.

## Verification

From the repository root, run the standalone model checks:

```sh
dashboard_check_dir=$(mktemp -d "${TMPDIR:-/tmp}/handover-state-checks.XXXXXX")
swiftc -module-cache-path "$dashboard_check_dir/module-cache" \
  Handover_V4/Models/DashboardPresentationState.swift \
  Tests/DashboardPresentationStateChecks.swift \
  -o "$dashboard_check_dir/checks"
"$dashboard_check_dir/checks"
```

Expected output: `Dashboard presentation checks passed`. Compile without `-Ounchecked`,
because these checks use Swift preconditions. They cover initial state, opening a
destination without closing another, clearing focus on collapse, toggling all,
and reopening a destination after collapse-all.

Build the application using a worktree-specific derived-data directory:

```sh
xcodebuild -project Handover_V4.xcodeproj -scheme Handover_V4 \
  -destination 'generic/platform=visionOS Simulator' \
  -derivedDataPath /private/tmp/handover-codex-isbar-derived-data \
  CODE_SIGNING_ALLOWED=NO build
```

Other agents should use a different derived-data path to avoid sharing build outputs.
Visual review on visionOS should cover all five case records, long Assessment content,
narrow/wide windows, navigation after collapse-all, and vitals visibility while scrolling.

### Verification status

The initial implementation passed the standalone checks and a generic visionOS
Simulator build on 6 September 2026. Device/simulator visual interaction review
has not yet been performed. These results do not verify future merged UI changes.

## Integration with the UI worktree

Codex's current worktree is on `codex/isbar-dashboard-model`; Claude's UI work
is in another worktree. Each agent edits its assigned folder only.
Worktrees isolate uncommitted files, but merging edits to the same files still
requires reconciliation. In particular, preserve the model-owned disclosure
rules when combining changes to ISBARSection and PatientDashboardView.

AGENTS.md and this document are currently working-tree files. They only become
available in another worktree after an explicit copy or integration of a commit;
creating them here does not update Claude's instructions automatically.

## Deferred

Immersive dashboard mounting, selected-patient lifetime changes, loader redesign,
simulation-time changes, and any new clinical schema fields are separate work.
