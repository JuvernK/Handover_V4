# Handover dashboard

Current implementation contract. Repository-wide rules live in [AGENTS.md](../AGENTS.md).

## Behavior to preserve

- Patient identity, diagnosis, demographics, acuity, trajectory, code status, and
  allergies form a permanent introduction with no disclosure control.
- At least 1100 pt wide and 650 pt high: header pinned above the main scroll region,
  ISBAR rail on the left, independently scrolling systems pane on the right.
  Rail and systems start 32 pt below the main pane; all panes share one window.
- Narrower or shorter: one scroll region, scrolling header, horizontal shortcuts,
  and systems between Assessment and Recommendation.
- Situation, Background, Assessment, Recommendation each show a full authored
  summary. Details start closed and expand independently by tapping the header.
- S/B/A/R opens and scrolls to its section without closing others. I returns to
  the reader's top when wide or the header when compact. ALL expands/collapses
  the four detail groups. Disclosure stays local to the view lifetime.
- Assessment details contain vitals with 12-hour histories, labs, infusions, and
  invasive devices. Systems follow `BodySystem.allCases` head-to-toe order;
  summaries remain visible and concerns expand independently. Spatial systems
  cards retain their adaptive grid and fully visible concerns.
- Appearance defaults dark, persists under `dashboardUsesDarkAppearance`, and
  applies locally to dashboard views. Switching must preserve disclosure and
  scroll position. Shared cards retain standalone glass outside the dashboard.

## Data and ownership

Cases come from `PatientData.json`, selected manually through
`AppModel(initialBedNumber:)`. Optional `Patient.handoverSummaries` fields accept
missing/null values. Missing or blank summaries show “No handover summary recorded.”;
blank system summaries show “No assessment recorded.” Never synthesize clinical
conclusions. All five cases have draft summaries requiring case-author review,
including whenever their underlying records change.

Paths below are relative to `Handover_V4/`.

| File | Owns |
| --- | --- |
| `Models/Patient.swift`, `Data/PatientData.json` | Clinical records and authored summaries |
| `Models/DashboardPresentationState.swift` | Local ISBAR focus and disclosure rules |
| `View/Dashboard/PatientDashboardView.swift` | Responsive layout, state ownership, private navigation and section views, summary fallback and card grouping |
| `View/Dashboard/PatientHeaderView.swift` | Shared patient introduction |
| `View/Cards/SystemAssessmentCard.swift` | Dashboard and spatial systems presentations |
| `View/Dashboard/DashboardView.swift` | Window controls, appearance preference, SharePlay alert, empty state |
| `View/Dashboard/DashboardTheme.swift` | Asset palette and dashboard/standalone surfaces |

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
│     ├─ ISBARNavColumn (private shortcuts)
│     ├─ ISBARSectionView (private summaries/disclosure) → clinical cards
│     ├─ PatientHeaderView
│     └─ SystemsAssessmentCard (sidebar)
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
  -derivedDataPath /private/tmp/handover-html-colors-derived-data \
  CODE_SIGNING_ALLOWED=NO build
```

Last code validation (7 September 2026): presentation-state and patient-summary
checks and a generic visionOS Simulator build passed after file consolidation.
The 6 September BED-02 simulator screenshots covered wide layout and both palettes;
visual checks were not repeated after consolidation.

Still unverified: all-case appearance, manual detail/concern disclosure, repeated
navigation and scrolling, narrow/short resizing, appearance persistence during
interaction, immersive visuals, and device gaze/pinch. Automated mouse interaction
was blocked by macOS assistive-access permissions. Passing model checks does not
establish these behaviors or participant comprehension.

## Deferred work

Immersive dashboard mounting, shared disclosure, note editing/authorship, loader
redesign, and simulation-time changes remain separate work. Evaluate whether users
can identify the main problem, concerns, and next actions, and whether the systems
pane helps narration or divides attention. Comprehension benefits are unvalidated.
