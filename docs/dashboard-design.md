# Handover dashboard

Current implementation contract. Repository-wide rules live in [AGENTS.md](../AGENTS.md).

## Behavior to preserve

- Patient identity, diagnosis, demographics, acuity, trajectory, code status, and
  allergies form a permanent introduction with no disclosure control.
- At least 1280 pt wide and 650 pt high: a separate patient introduction stays
  pinned above a masonry SBAR board — Situation, Background, Assessment, and
  Recommendation drop into whichever column currently has the least height,
  the way a Pinterest-style grid fills space, rather than fixed lanes. Assessment
  always spans two columns (it carries vitals/labs/infusion grids that need the
  width); Situation, Background, and Recommendation are always one column wide.
  The board uses 2 columns normally and up to 3 once there is enough room. Column
  assignment is recomputed on every expand/collapse, so a card can move to a
  different column as its siblings free or claim space — this reshuffling is a
  deliberate choice, not a bug, made after seeing it live in a prototype
  (`docs/mockups/dashboard-flowboard.html`). Each card also has a grip handle
  (next to its chevron) that can be dragged onto another card to swap the two
  cards' positions in the board order; the masonry layout then repositions
  everything around the new order, same as an expand/collapse. This order is
  in-memory only (`PatientDashboardView.sectionOrder`), not persisted or shared.
  The SBAR rail aligns with the top of the introduction, 8 pt to its left. The
  systems pane is 400 pt wide, top-aligned, and scrolls independently up to
  min(720, window height − 120) pt, with a 46 pt top inset. Its 26 pt overlap is
  reserved as empty space beside the board, with the existing 12 pt forward depth
  offset. All panes share one window. New windows default to 1440 × 860 pt.
- The introduction puts status and allergy information beside identity when it
  fits, and below it otherwise. Native section buttons provide rounded hover
  feedback; the focused section has an accent outline. Authored summaries stay
  fully visible in both disclosure states.
- Narrower or shorter: one scroll region, scrolling header, horizontal shortcuts,
  and a separate systems panel between Assessment and Recommendation. The shortcut row scrolls
  horizontally when its enlarged controls exceed the available width. This mode keeps
  the plain single-column stack (no masonry) since there isn't room for multiple columns.
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

### Why masonry, not the two-lane board

The two-lane 40/60 split (a prior iteration of this doc) was built from an HTML
reference and shipped without checking it against what was actually wanted. A
`/grilling` session on 2026-09-08 established that the two-lane split was the
wrong structure entirely: the four SBAR cards should each take up only the space
their own content needs, not a lane sized for the other cards sharing it. The
options considered and rejected: equal-height row layout (cards forced to match
neighbours' height — rejected, wastes space); fixed-slot masonry where a card's
column never changes (rejected — the user explicitly chose full reshuffling
after being warned it could make cards move mid-handover); equal-width columns
only (rejected — Assessment needed to span wider for its data grids).

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
| `View/Dashboard/FlowBoardLayout.swift` | `PatientDashboardView -> FlowBoardLayout -> masonry placement of SBAR cards` | Masonry column placement (2-3 cols, or 1 when narrow) for the SBAR board; lets a card span multiple columns via `flowSpan(_:)` |
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
│     ├─ DashboardPresentationState + pending scroll request
│     ├─ ISBARNavColumn (private shortcuts) — S/B/A/R toggle their section; ALL toggles all four
│     ├─ FlowBoardLayout (wide mode only) → ISBARSectionView × 4 (private summaries/disclosure) → clinical cards
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
  -derivedDataPath /private/tmp/handover-v2-derived-data \
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

Drag-to-swap validation (8 September 2026): after the two rail bug fixes above
(rail toggling closed, and narrow windows keeping the same composition), a grip
handle (`line.3.horizontal`, next to each card's chevron) and `.draggable`/
`.dropDestination` swap handling were added to `ISBARSectionView`. The build
succeeded and a fresh install was screenshotted, confirming the grip handle
renders correctly next to the chevron on every card. The actual drag gesture —
picking up a handle, dropping it on another card, and watching the swap +
reflow — was **not** exercised, for the same simulator tap/drag limitation as
everything else in this file; only the static rendering was confirmed.

## Deferred work

### Layout exploration (7 September 2026)

#### Header dragging and sorting

**Partially implemented (2026-09-08):** the core idea — drag a card's header onto
another card to move it — now exists in Swift, but as a plain two-card position
swap (see "Behavior to preserve" above and `ISBARSectionView.onSwap` in
`PatientDashboardView.swift`), not the fuller insert-before-with-region-reflow
behavior this HTML draft explored. Treatment plan sorting, the demo due-date
defaults, and eight-card region dragging below are still just this HTML proposal,
not implemented.

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
