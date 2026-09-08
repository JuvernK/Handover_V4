# Handover dashboard

Current implementation contract. Repository-wide rules live in [AGENTS.md](../AGENTS.md).

## Behavior to preserve

- Patient identity, diagnosis, demographics, acuity, trajectory, code status, and
  allergies form a permanent introduction with no disclosure control.
- When the window is at least 650 pt high and leaves 280 pt for the board, the
  patient introduction stays pinned above the SBAR board. The board uses one
  column when narrow, two normally, and three above 1400 pt available width.
  Each expanded section is measured at one and two columns. It spans two when
  its one-column height exceeds 560 pt and widening reduces height by at least
  15%. Collapsed sections use one column. This applies to all four sections.
- Cards pack in local section order. Reordering reuses `main`'s
  `DraggableDashboardCard` / `HandoverViewModel.moveSection` structure: a typed
  drag payload lands on a card, whose destination identity updates the order.
  Dragging a section to another section moves it to that section's original
  index and shifts intervening sections. This is insertion, not a pairwise
  exchange of screen coordinates. Both responsive layouts use this transition.
- The 60 × 60 pt grip remains separate from disclosure. The destination card
  shows an accent outline. Empty-space drops have no destination and do nothing;
  no landing area is reserved. Introduction and systems remain fixed.
  Disclosure, reordering, and resizing repack the board with content-driven spans.
  Ordering stays local to the dashboard lifetime and is not sent through SharePlay.
- Layout sizing follows `main`'s finite-width resolution pattern: unspecified or
  nonfinite proposals use a finite 280 pt per-column measurement basis plus gaps.
  Finite proposals use the available width. No measured screen positions are
  persisted, and no floating-point coordinate is converted into a column index.
- The SBAR rail sits beside the board. The systems pane is 400 pt wide, top-aligned,
  and scrolls independently up to min(720, window height − 120) pt, with a 46 pt
  top inset. Its 26 pt overlap is reserved as empty space beside the board, with
  the existing 12 pt forward depth offset. All panes share one window. New windows
  default to 1440 × 860 pt.
- The introduction puts status and allergy information beside identity when it
  fits, and below it otherwise. Native section buttons provide rounded hover
  feedback; the focused section has an accent outline. Authored summaries stay
  fully visible in both disclosure states.
- Narrower or shorter: one scroll region, scrolling header, horizontal shortcuts,
  and a separate systems panel between Assessment and Recommendation. The shortcut row scrolls
  horizontally when its enlarged controls exceed the available width. This mode keeps
  the plain single-column stack and supports card-to-card swaps in reading order;
  free-space positioning is available in the board composition.
- Situation, Background, Assessment, Recommendation each show a full authored
  summary. Details start **expanded** so a fresh handover shows full context
  immediately, and collapse independently by tapping the header.
- Rail buttons use 60 × 60 pt targets, 24 pt letters, and rounded native hover
  highlights matching their visible shapes. ALL uses the same target size.
- The rail contains S/B/A/R and ALL; the redundant I shortcut is removed in both
  layouts. S/B/A/R opens and scrolls to its section without closing others. ALL
  expands/collapses the four detail groups. Disclosure stays local to the view lifetime.
- Expanded labs, infusions, devices, and treatment tasks use adaptive grids of
  rounded tiles. Labs emphasize values with units, trend arrows, and explicit
  severity text. Infusions keep dose, route, purpose, and high-alert labels together.
  Task tiles retain authored priority order and due times. Narrative sections remain
  full-width. Spatial cards retain their existing row presentations.
- Assessment details contain vitals with 12-hour histories, labs, infusions, and
  invasive devices. Systems follow `BodySystem.allCases` head-to-toe order;
  summaries remain visible and concerns expand independently. Spatial systems
  cards retain their adaptive grid and fully visible concerns.
- Appearance defaults dark, persists under `dashboardUsesDarkAppearance`, and
  applies locally to dashboard views. Switching must preserve disclosure and
  scroll position. Shared cards retain standalone glass outside the dashboard.

### Layout history

The earlier two-lane split was replaced by content-sized masonry on 8 September.
An intermediate drag implementation stored displayed positions and supported
empty-space moves; empty-space moves were then removed at the user's request.
A reported nonfinite-coordinate crash led to reusing `main`'s identity/order-based
card drop structure and finite-width resolution. The current layout retains
content-driven spans and masonry packing rather than copying `main`'s row layout.

## Data and ownership

Cases come from `PatientData.json`, selected manually through
`AppModel(initialBedNumber:)`. Optional `Patient.handoverSummaries` fields accept
missing/null values. Missing or blank summaries show “No handover summary recorded.”;
blank system summaries show “No assessment recorded.” Never synthesize clinical
conclusions. All five cases have draft summaries requiring case-author review,
including whenever their underlying records change.

Paths below are relative to `Handover_V4/`. Each dashboard-related Swift file starts
with a `// Flow: <upstream> -> <this file> -> <downstream>` comment; the Flow column
below is copied from that comment so this table and the code can't drift apart silently.

| File | Flow | Owns |
| --- | --- | --- |
| `Models/Patient.swift`, `Data/PatientData.json` | — | Clinical records and authored summaries |
| `Models/DashboardPresentationState.swift` | `PatientDashboardView -> DashboardPresentationState -> section detail disclosure` | Local ISBAR focus and disclosure rules; sections start expanded, and focusing an already-expanded section collapses it |
| `View/Dashboard/PatientDashboardView.swift` | `DashboardView -> PatientDashboardView -> ISBAR navigation + patient summaries + systems assessment` | Responsive layout, state ownership, private navigation and section views, summary fallback and card grouping |
| `Models/DashboardBoardState.swift` | `PatientDashboardView -> DashboardBoardState -> local section order; FlowBoardLayout -> DashboardBoardGeometry -> measured frames` | Main-style order transitions, finite-width resolution, content-driven spans, and collision-free packing |
| `View/Dashboard/FlowBoardLayout.swift` | `PatientDashboardView -> FlowBoardLayout -> DashboardBoardGeometry -> measured SBAR frames` | SwiftUI measurement at one and two columns and placement through the shared geometry solver |
| `View/Dashboard/PatientHeaderView.swift` | `Patient records -> PatientHeaderView -> DashboardTheme + SwiftUI presentation` | Shared patient introduction with a dashboard-only side-by-side safety layout when space permits |
| `View/Cards/SystemAssessmentCard.swift` | `Patient records -> SystemAssessmentCard -> DashboardTheme + SwiftUI presentation` | Dashboard and spatial systems presentations |
| `View/Dashboard/DashboardView.swift` | `AppModel -> DashboardView -> PatientDashboardView + DashboardControls` | Window controls, appearance preference, SharePlay alert, empty state |
| `View/Dashboard/DashboardTheme.swift` | `HTML reference -> DashboardTheme -> dashboard panels, badges and clinical cards` | Asset palette and dashboard/standalone surfaces |
| `View/Dashboard/DashboardTileGrid.swift` | `Clinical cards -> DashboardTileGrid -> DashboardTheme item surfaces` | Responsive columns and rounded item surfaces for dashboard records |

## Current ownership and relationships

The app owns shared state and hosts two view trees. Indentation below shows
ownership or composition; arrows show data flow or rendering delegation.

```text
Handover_V4App
├─ AppModel (shared state)
│  ├─ HandoverViewModel → PatientDataLoader → PatientData.json
│  ├─ SessionController ↔ SharePlay messages
│  └─ Immersive lifecycle, card states/positions, sync conflict counters
├─ DashboardView (window)
│  ├─ DashboardControls → ToggleImmersiveSpaceButton
│  └─ PatientDashboardView
│     ├─ DashboardPresentationState + DashboardBoardState + pending scroll request
│     ├─ ISBARNavColumn (private shortcuts) — S/B/A/R toggle their section; ALL toggles all four
│     ├─ FlowBoardLayout (board mode) → ISBARSectionView × 4 (private summaries/disclosure) → clinical cards
│     ├─ PatientHeaderView
│     └─ SystemsAssessmentCard (floating, overlapping panel)
└─ ImmersiveView (RealityKit scene, attachments, gestures)
   └─ AttachmentsProvider → SpatialCardView
      ├─ PatientHeaderView (basic information)
      └─ SectionID.view(for:) → shared clinical cards
```

`HandoverViewModel` owns the displayed patient and shared section order; both view
trees read it. `AppModel` coordinates remote updates and catch-up through
`SessionController`. Local ISBAR disclosure is separate from shared spatial card
disclosure. `SectionID` remains a spatial/SharePlay identifier, distinct from
`ISBARSectionID`, even though the dashboard no longer renders the shared order.

Clinical cards own their rows and empty states. `VitalsCard` delegates to
`VitalBox` → `Sparkline`; `CardHeader` and `DashboardTheme` supply shared styling.
Situation and Family currently render only in dashboard sections; the other
clinical cards and patient header also render spatially. Authored POI names map
through `SpatialCardView`; preserve those names and SharePlay message types.

## Validation

Run from the repository root. Keep tests outside the synchronized app folder to
avoid a second executable entry point. Use separate output paths per worktree;
never compile precondition-based checks with `-Ounchecked`.

```sh
swiftc -module-cache-path /private/tmp/handover-drag-module-cache \
  Handover_V4/Models/DashboardPresentationState.swift \
  Handover_V4/Models/DashboardBoardState.swift \
  Tests/DashboardBoardChecks.swift \
  -o /private/tmp/handover-board-checks
/private/tmp/handover-board-checks

swiftc -module-cache-path /private/tmp/handover-summary-module-cache \
  Handover_V4/Models/DashboardPresentationState.swift \
  Tests/DashboardPresentationStateChecks.swift \
  -o /private/tmp/handover-summary-state-checks
/private/tmp/handover-summary-state-checks

swiftc -module-cache-path /private/tmp/handover-summary-module-cache \
  Handover_V4/Models/Enums.swift \
  Handover_V4/Models/Patient.swift \
  Handover_V4/Data/PatientDataLoader.swift \
  Tests/PatientSummaryChecks.swift \
  -o /private/tmp/handover-patient-summary-checks
/private/tmp/handover-patient-summary-checks

xcodebuild -project Handover_V4.xcodeproj -scheme Handover_V4 \
  -destination 'generic/platform=visionOS Simulator' \
  -derivedDataPath /private/tmp/handover-drag-derived \
  CODE_SIGNING_ALLOWED=NO build
```

Masonry board validation (8 September 2026): the design was interviewed via
`/grilling` before any Swift was touched, then proven as an HTML prototype
(`docs/mockups/dashboard-flowboard.html`, using placeholder BED-02 content) and
approved before implementation. That prototype pass caught a real bug — board
text bled through the systems panel because CSS padding doesn't constrain
absolutely-positioned children, only content-box children — fixed there before
porting the approach to `FlowBoardLayout.swift`.

In Swift: `DashboardPresentationStateChecks` was updated for the new
starts-expanded default and passed. The generic visionOS Simulator build passed,
then a real build was installed and launched on a booted `Apple Vision Pro`
simulator (visionOS 26.2) and screenshotted for BED-02: the masonry board,
letter-badged cards starting expanded, wide rail (S/B/A/R/ALL, 60×60 targets),
and the overlapping systems panel all render as designed. Rail and systems panel
visually match `latest-prototype`, confirmed by diffing `DashboardTheme.swift`
and `SystemAssessmentCard.swift` against that branch (no changes needed there).

Not exercised in this pass: tapping a card header to collapse/expand and watch
column reflow live (Automated tapping is blocked by macOS assistive-access
permissions on this simulator, same limitation as prior passes); concern
disclosure interaction; the narrow/short single-column fallback (unchanged from
before, but not re-screenshotted); 3-column behavior at very wide window sizes
(only the 1440×860 default was screenshotted); all-case appearance; appearance
persistence during interaction; device gaze/pinch. The HTML prototype exercised
click-to-collapse and reflow, and 2-vs-3-column switching, but that is a stand-in
for the interaction, not a substitute for verifying the native gesture path.

Drag revision (8 September 2026): the pre-change simulator was captured. After
correcting multi-display pointer coordinates and confirming ALL accepted taps,
attempting to drag the small Situation grip into empty space expanded Situation
instead of moving it. This exposed an end-user targeting failure; it did not prove
that the original drop callback ran. Code inspection also found that only card
drops were handled, swaps changed array order rather than displayed positions,
and widths were hard-coded by section identity.

Current regression checks cover forward/backward insertion, adjacent moves,
self/invalid identities, content-driven spans, and 240 repeated reorder/content
changes at one to three columns. Nonfinite sizing regressions run after a reorder:
unspecified, positive/negative infinity, NaN, zero, and negative proposals must
produce finite frames, and subsequent finite placement must remain valid.

The main-style revision removes the coordinate-to-Int conversion shown in the
user's crash screenshot. The root cause is consistent with an infinite SwiftUI
sizing probe reaching the stored-position calculation; exact device proposal
values were not captured. Both order and disclosure checks passed, and the generic visionOS Simulator
build passed for this revision. Native headset drag completion remains unverified;
the prior simulator pointer attempts did not complete a move. No claim of native
end-to-end gesture success is made by the standalone geometry checks.

Manual acceptance checks:
1. Collapse ALL and drag Situation onto Recommendation. Order should become
   Background, Assessment, Recommendation, Situation without changing disclosure.
2. Move Situation back onto Background. Original SBAR order should return.
3. Drop onto the source card or empty space. Order should remain unchanged.
4. Expand sections, resize the window, and repeat while immersive space is open.
   Cards must repack without a nonfinite-coordinate crash or clipped content.

## Deferred work

### Layout exploration (7 September 2026)

#### Header dragging and sorting

**Implemented for SBAR sections (2026-09-08):** dedicated grips support visible
main-style order moves with automatic content-driven width. Empty-board placement
was removed at the user’s request.
The eight-card region layout and treatment-plan sorting below remain proposals.

[Interactive HTML draft](mockups/dashboard-draggable.html) keeps the user-selected
integrated arrangement, infusion tiles and two nested Escalation blocks. This is
an HTML proposal only; no Swift presentation behavior has changed.

- Eight cards move between layout regions by dragging their headers onto another
  card, inserting before that card. Dropping in a region's open area appends.
  Separate drag handles and destination menus were removed at the user's request.
  Header clicks still disclose sections; drag gestures suppress the following click.
  Reset layout restores starting positions. The patient introduction stays fixed.
- Treatment plan uses sorting, superseding the earlier filtering proposal.
  Options: authored order, priority (urgent first, due date as secondary order),
  earliest due and latest due. Every task stays visible; equal keys retain authored
  order. Full timestamps are compared, including timezone offsets.
- The embedded HTML case supplies missing due dates with the demo default
  `2026-04-28T12:00:00+10:00`. All four affected records explicitly show Demo default.
  Missing priorities would default to routine. `PatientData.json` is unchanged.
- Systems assessment retains the native sidebar's rounded individual cards,
  purple system icons, head-to-toe order, persistent summaries and separate concern
  disclosure. Cards without concerns have no disclosure button. HTML icons are
  approximations of the app's SF Symbols.
- Cards size to available width. Three main columns become two below 1400 px and
  one below 900 px; the rail becomes horizontal in the single-column layout.
  Vitals, infusion tiles and supporting columns wrap. Text keeps its readable size;
  content height remains natural. Short windows permit document scrolling.
- Layout, sort order and concern disclosure survive rerenders and resizing.
  They are not persisted across reloads or shared through SharePlay.

Validation: syntax and whitespace checks passed. Chrome automation verified eight
header drag targets, removal of handle/menu/filter controls, four labelled defaults,
priority ordering, ascending/descending dates with all seven tasks retained, six
system cards and icons, concern disclosure, and synthetic header drag preserving
sort/disclosure state. Width checks at 1800, 1200, 800 and 390 px found no horizontal
overflow and retained every task. The wide browser rendering was visually inspected.
Native pointer dragging, narrow visual inspection, Safari interactions, visionOS
gaze/pinch, keyboard-only rearrangement and all-case behavior remain unverified.
No app build was needed because Swift files were not changed.

#### Earlier integrated study

The user rejected the three options below. After reading the minor thesis and Echo,
a replacement [integrated HTML draft](mockups/dashboard-integrated.html) brings
clinical findings, infusions and plan items into one overview. The SBAR rail opens
and highlights groups in place with independent disclosure. The proposal starts
expanded. It has not been approved or implemented in SwiftUI.
See [research rationale](mockups/research-rationale.md) for source sections, design
inferences and evidence limits. The browser snapshot uses BED-01 only; all-case,
large text, native interaction and shared presentation remain unvalidated.
The expanded BED-01 overview was visually inspected in Chrome at 1600 × 1000;
all seven plan items and all five line records fit in that viewport. At 1440 × 860,
content still extends below the viewport. Therefore this draft does not yet solve
the native default-window fit requirement. No content is clipped deliberately;
document scrolling remains available. Click interactions and expanded concerns
have not been exercised in a browser. Syntax and whitespace checks passed.

#### Rejected options

[Interactive HTML layout study](mockups/dashboard-options.html) compares a fixed
summary/detail split, an adaptive SBAR board, and section pages. This is a proposal
awaiting design sign-off, not implemented SwiftUI behavior. The self-contained
draft embeds BED-01 from `PatientData.json`; regenerate that snapshot if the case
changes. It adds no patient picker.

All options retain the introduction and SBAR rail, but propose showing one detail
section at a time, with tabs and explicit record/system pages. ALL returns to a
summary overview instead of expanding everything. These are deliberate changes
to the current independent section disclosure contract and need approval.
The split keeps all summaries visible during detail reading; the board moves them;
section pages hide the other summaries. System concern disclosure remains independent.

The desktop draft targets widths of at least 1200 px. Smaller windows permit
document scrolling; Dynamic Type, arbitrary narrative length, all-case fitting,
and native gaze/pinch behavior still need design and validation. No Swift files
changed, so no app build or presentation-state checks are required for this draft.
JavaScript syntax and whitespace checks passed. A Chrome screenshot of the initial
split layout at 1440 × 1000 was inspected; its footer overlap prompted a taller
draft workspace. The adjusted rendering and interactive states have not been
visually rechecked. This browser study does not establish fit at the app's native
1440 × 860 default size.

Immersive dashboard mounting, shared disclosure, note editing/authorship, loader
redesign, and simulation-time changes remain separate work. Evaluate whether users
can identify the main problem, concerns, and next actions, and whether the systems
pane helps narration or divides attention. Comprehension benefits are unvalidated.
