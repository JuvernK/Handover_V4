# Presentation modes

Agreed design, not implemented. Updated 8 September 2026.

Do not implement the mode switch until Orbit has landed on `latest-prototype`
and the user explicitly requests implementation. Recheck this plan against that
branch when work resumes. Use `main` as a reference, not as code to merge wholesale.

## Modes and controls

The three mutually exclusive modes support a headset user study:

- **Spatial**: cards at fixed patient/room points of interest. Card behavior and
  pending visual design are in [spatial-cards.md](spatial-cards.md).
- **Orbit**: cards arranged in a rotating carousel.
- **Dashboard**: the dashboard window inside immersion. Hide spatial cards and
  the orbit ring, keeping the ICU room visible. No standalone dashboard outside
  immersion.

Default to Spatial on entering immersion outside an existing shared session.
A participant-visible `Spatial | Orbit | Dashboard` segmented control lives in
the persistent launcher/control window. Any participant can switch modes.

Show only the active mode's controls in that window: SBAR in Spatial, carousel
controls in Orbit, and no extra card controls in Dashboard (which has its own
SBAR rail). Hide inactive controls. Mode switch, Exit, and SharePlay remain visible.

## State and SharePlay

Each mode entry resets disclosure to expanded, including returning to a mode
within the same session. Do not persist disclosure across app restarts.

Future SharePlay synchronizes mode changes, individual/group card toggles,
scrolling, and Orbit navigation. Any participant's actions update everyone.
Head movement, gaze, viewer-facing card orientation, and personal window placement
remain local. Late joiners inherit the session's current mode, disclosure,
scroll position, and Orbit navigation without resetting anyone. The reset occurs
on a shared mode change, not on joining.

These are future requirements, not current synchronization behavior. TODOs at
`DashboardPresentationState.expandedSections` and `AppModel.cardStates` mark the
follow-up. Simultaneous-action conflict rules remain undecided.

Use a distinct `PresentationMode { spatial, orbit, dashboard }`; do not put mode
selection into Orbit-only state carrying rotation or focused-card fields.
The original reference is `main`'s
`Handover_V4/SharedState/SharedHandoverReplicator.swift`: replicate a presentation
mode fact using the existing pattern. That file is not present on this branch;
re-evaluate the integration once Orbit lands. Each device reacts to shared mode
changes with local window open/dismiss actions.

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
No source files have been moved. All modes use the same patient cases.
Canonical terms live in [CONTEXT.md](../CONTEXT.md).
