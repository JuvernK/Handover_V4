# Presentation modes

Agreed design. Updated 26 October 2026.

The three-way mode switch, Spatial cards, Orbit carousel, disclosure resets,
source outlines, and `Presentation/` source organization are implemented on
`main`. SharePlay synchronization of these behaviors is implemented on
`feature/shareplay-snapshot`; see [SharePlay](shareplay.md). See
[Orbit and source outlines](orbit-source-outlines.md) for Orbit implementation and
validation details.

## Modes and controls

The three mutually exclusive modes support a headset user study:

- **Spatial**: cards at fixed patient/room points of interest.
- **Orbit**: nine clinical cards, including Situation, arranged in a rotating
  carousel, with Basic Information permanently visible separately. The
  [Orbit and source-outline implementation](orbit-source-outlines.md) records the
  migration decisions and validation.
- **Dashboard**: the dashboard window inside immersion. Hide spatial cards and
  the orbit ring, keeping the ICU room visible. No standalone dashboard outside
  immersion.

Default to Dashboard on entering immersion outside an existing shared session. A participant-visible
` Dashboard | Spatial | Orbit ` segmented control lives in the persistent
launcher/control window. Any participant can switch modes.

Show only the active mode's controls in that window: SBAR in Spatial, carousel
controls in Orbit, and no extra card controls in Dashboard (which has its own
SBAR rail). Hide inactive controls. Mode switch, Exit, and SharePlay remain visible.
The SharePlay button reads Start SharePlay, or Leave SharePlay during a session.

## State and SharePlay

Entering Spatial or Dashboard resets all clinical sections to expanded,
including returning to a mode within the same session. Orbit is the exception:
each entry starts on Situation with all nine clinical cards collapsed, then
expands only Situation after the carousel settles. Basic Information remains
permanently visible separately. Do not persist disclosure across app restarts.

SharePlay shares the mode, disclosure, SBAR focus, section order, Orbit card and
ICU entry with everyone, and any participant can change them. Head movement, gaze,
viewer-facing card orientation, personal window placement and dashboard free
scrolling stay local. A mode change carries its reset to peers; joining never
resets anyone. Simultaneous changes resolve to the later snapshot. Details,
conflict behavior and validation are in [SharePlay](shareplay.md).

`PresentationMode { dashboard, spatial, orbit }` is its own type
(`Controls/PresentationMode.swift`), separate from Orbit state. Each device reacts
to a shared mode change with its own window open and dismiss actions in
`LauncherView`.

## Approved source organization

Group each mode's views, state, layout, and interactions together:

```text
Handover_V4/Presentation/
  Dashboard/
  Spatial/
  Orbit/
  Shared/       # Reusable presentation content and styling
  Immersive/    # ICU scene and points of interest
  Controls/     # Launcher, mode switch, enter/exit
```

Clinical models, data loading, and SharePlay remain outside individual modes.
All modes use the same patient cases.

Implemented: `Dashboard/` (dashboard
view, tile grid, board/presentation state), `Spatial/` (`SpatialCard.swift`,
`SBARGroup.swift`), `Shared/` (`CardHeader`, `DashboardTheme`,
`PatientHeaderView`, `SectionID`, and `Cards/` — reused by both Dashboard and
Spatial), `Immersive/` (`ImmersiveView`, attachment/POI plumbing), `Controls/`
(`LauncherView`, `ToggleImmersiveSpaceButton`, `PresentationMode`). `Orbit/` now contains navigation controls, controller/state, and authored-path
geometry. `AppModel.swift`, `Handover_V4App.swift`,
`Models/Patient.swift`, `Models/Enums.swift`, `Data/`, `SharePlay/`, and
`ViewModels/` stayed put, per "remain outside individual modes" above.
Canonical terms live in [CONTEXT.md](../CONTEXT.md).
