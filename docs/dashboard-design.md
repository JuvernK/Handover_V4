# Handover dashboard

## Current design

The prototype supports giving a structured handover. Patient identity and diagnosis
form a permanent introduction at the top of the wider SBAR reading pane. A narrower
systems assessment pane sits beside it, like the former Current Vitals panel. The familiar ISBAR shortcut rail sits to the left of the reading column; systems
occupy the former vitals side panel.

Each SBAR section leads with an authored, patient-specific sentence. Supporting
records expand by tapping the section header and its chevron, matching the original
interaction. All four summaries are
visible initially; detail sections start closed and open independently.

The approach borrows the main-point-first structure of the
[Minto Pyramid Principle](https://barbaraminto.com/). Improved comprehension and
lower cognitive load are design hypotheses, not validated outcomes.

## Layout and interaction

- The patient header contains name, main diagnosis, demographics, bed, MRN, ICU day,
  acuity, trajectory, code status, and allergies. It has no disclosure control.
- At widths of at least 1100 points and heights of at least 650 points, the header
  stays at the top of the main pane, above its scroll region. The systems pane
  is a sibling scroll region; main-content scrolling cannot move it. The rail and
  systems panel start 32 points below the main pane, with clear gaps between them.
  All panes belong to the same window and move/resize together.
- The ISBAR rail includes I, S, B, A, R, and ALL. Selecting S/B/A/R opens and scrolls
  to that section without closing others. I returns the reading pane to the top in
  wide windows (the patient header is already visible); in compact windows it
  scrolls to the patient header. ALL expands or collapses the four detail sections.
  Introduction remains permanently available.
- The left column follows Situation, Background, Assessment, Recommendation.
  Summaries wrap without line limits, even with details closed.
- Assessment details contain current vitals with 12-hour histories, labs,
  infusions, and invasive devices. Systems are not duplicated inside this section.
- The right column follows the fixed `BodySystem.allCases` head-to-toe order.
  Full authored system summaries remain visible; additional concern lists can
  expand individually. A blank system summary says “No assessment recorded.”
- In narrow or short windows, all content shares one scroll region. The patient
  header scrolls with it, shortcuts form a horizontal row, and systems appear after
  Assessment, before Recommendation.
  This keeps content reachable when a pinned header would consume too much height.
- Selecting the patient remains a manual `AppModel(initialBedNumber:)` configuration.
  No patient picker, runtime summary generation, or clinical note editor is included.
- Disclosure is local to the view lifetime and is not shared through SharePlay.
  Existing spatial card IDs, authored POI names, and SharePlay messages are unchanged.

## Authored summary data

`Patient.handoverSummaries` contains optional `situation`, `background`,
`assessment`, and `recommendation` strings. Each is one concise main point, with
supporting facts retained in the existing structured records. These are case
content, while expansion state belongs to `DashboardPresentationState`.

All five bundled cases have draft summaries based on their existing records.
No original observations, treatments, or thresholds were changed. The intentionally
incomplete demonstration case explicitly describes its missing information.
The summaries need case-author review before participant evaluation. They are
not signed nursing notes and carry no invented authorship or time.

Missing `handoverSummaries`, missing individual fields, and null fields decode
without breaking older cases. Missing or whitespace-only text displays
“No handover summary recorded.” The UI does not synthesize a clinical conclusion.
When case records change, their authored summaries must be reviewed as well.

Example from the septic-shock case:

```json
"handoverSummaries": {
  "situation": "Septic shock from pneumonia is worsening, with high vasopressor requirements and declining renal function.",
  "background": "Pneumonia followed fever and productive cough, against a background of diabetes, obesity, asthma, and recurrent respiratory infections.",
  "assessment": "Oxygenation is deteriorating, with rising lactate and creatinine.",
  "recommendation": "The plan prioritises repeat lactate, review of sputum cultures, and reassessment of organ support needs."
}
```

## File responsibilities

Paths are relative to the repository root.

| File | Responsibility |
| --- | --- |
| `Handover_V4/Data/PatientData.json` | Authored cases and draft section summaries |
| `Handover_V4/Models/Patient.swift` | Clinical record schema, including optional summaries |
| `Handover_V4/Models/DashboardPresentationState.swift` | Five navigation destinations, four detail groups, focus, and independent disclosure state |
| `Handover_V4/View/Dashboard/PatientDashboardView.swift` | Header, responsive columns, and local state ownership |
| `Handover_V4/View/Dashboard/PatientHeaderView.swift` | Permanent patient identity and safety context |
| `Handover_V4/View/Dashboard/ISBARNavColumn.swift` | Familiar ISBAR shortcuts and ALL control |
| `Handover_V4/View/Dashboard/ISBARSection.swift` | Summary selection, missing-text fallback, detail controls, and clinical-card grouping |
| `Handover_V4/View/Cards/SystemAssessmentCard.swift` | Head-to-toe sidebar; retains adaptive grid and visible concerns for standalone spatial cards |
| `Handover_V4/View/Dashboard/DashboardTheme.swift` | HTML palette, dark outer panes, nested card surfaces |
| `Handover_V4/View/Dashboard/DashboardView.swift` | Window controls, SharePlay alert, empty state |
| `Tests/DashboardPresentationStateChecks.swift` | Initial overview and independent detail transitions |
| `Tests/PatientSummaryChecks.swift` | All-case decoding, legacy/partial schema compatibility, and round-trip preservation |

The theme retains the HTML's lavender accent, coral critical indicators, amber
warnings, mint normal readings, and layered white text. Its OKLCH colors are
converted to sRGB (coral clipped to gamut). Dark violet/blue washes sit beneath
native outer glass; inner cards use quiet white fills and hairlines. Shared
clinical cards retain standalone native glass outside the dashboard.

## Appearance

The bottom ornament includes a **Light mode** / **Dark mode** button labelled with
its next action. Dark is the initial default; `@AppStorage` stores the choice under
`dashboardUsesDarkAppearance`. Changing appearance does not reset disclosure,
scroll position, or the systems panel. The preference is local to dashboard views,
not SharePlay or immersive-space presentation.

`Assets.xcassets/Dashboard*.colorset` stores light/dark variants of every palette
token, including text, borders, panel washes, and clinical colors. The light palette
uses the HTML's pale glass and deeper critical/warning/normal colors. Its purple
accent is also deepened, and secondary text darkened, for contrast on pale surfaces.
`DashboardTheme` resolves those assets using the dashboard's local color scheme.

## Validation commands

Run from the repository root. Tests live outside the synchronized app folder to
avoid including a second executable entry point in the application.

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

Compile checks without `-Ounchecked`, as they use preconditions. Other worktrees
must use separate derived-data and test-output paths.

## Validation status

The previous palette prototype passed model checks, built, and was reviewed in a
visionOS 26.2 simulator screenshot on 6 September 2026. That review does not validate
this new layout.

The summary-first update passed presentation-state and patient-summary checks
and a generic visionOS Simulator build on 6 September 2026. The app was installed
and launched in the visionOS 26.2 simulator. Screenshot review of the configured
BED-02 case confirmed the permanent header, all four untruncated summaries at the
default wide size, and the separate systems column. Screenshot:
`/private/tmp/handover-summary-first.png`. Existing SwiftLint configuration and
AppIntents metadata warnings remain; there were no build errors.

All-case visual review, manual detail/concern disclosure and scrolling,
narrow/short window interaction, immersive visual review, device gaze/pinch
testing, and participant comprehension testing have not yet been performed.

Navigation and appearance update: presentation checks passed, including focus,
returning to Introduction without disclosing it, repeat navigation, and ALL.
A generic visionOS Simulator build passed on 6 September 2026. The configured
BED-02 case was launched in each appearance using temporary launch arguments;
screenshots confirmed both palettes, the ISBAR rail, and the systems pane beside
the main reader. Captures: `/private/tmp/handover-restored-dark.png` and
`/private/tmp/handover-restored-light.png`. The app was relaunched normally afterward.

The main reader and systems pane have sibling scroll regions inside one window;
the patient header sits outside the main scroll region. Automated mouse-based
scroll/toggle verification could not run because macOS denied assistive access
to System Events. On-screen toggle persistence, repeated scrolling/navigation,
resizing, and device interaction still require manual review.

## Next evaluation

Ask participants to identify the main problem, current concerns, and next actions,
then give a structured handover. Observe searching, hesitation, omitted information,
and repetition. In particular, assess whether the persistent systems column aids
head-to-toe narration or divides attention, and whether summaries are sufficient
without opening every section. Use feedback to revisit density and vitals placement.

Immersive dashboard mounting, shared disclosure, note authorship/editing, loader
redesign, and simulation-time changes remain separate work.
