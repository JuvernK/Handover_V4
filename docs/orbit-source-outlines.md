# Orbit and source outlines

Implemented locally on `design/orbit-source-outlines`, updated 9 September 2026.
This document records the behavior and the separately deferred SharePlay work.
Related plans: [presentation modes](presentation-modes.md) and
[Spatial cards](spatial-cards.md). Domain terms live in [CONTEXT.md](../CONTEXT.md).

## Requested scope

Carry Orbit and source-reference highlighting from `main` into the
`latest-prototype` development baseline, reviewing and adapting the reference
implementation. Equipment highlighting must use outlines only.

## Confirmed decisions

- Orbit contains nine clinical cards in fixed SBAR reading order: Situation,
  Related Background, Vitals,
  Active Infusions, Lines & Access, Abnormal Labs, Systems Assessment,
  Treatment Plan, and Escalation. Dashboard rearrangement does not change this
  order.
- Entering Orbit starts on Situation. Joining an existing shared Orbit session
  follows the session's current navigation state, as required by the existing
  presentation-mode plan; it is not a new mode entry.
- Each Orbit entry, including returning from another mode, starts with all nine
  clinical cards collapsed, then expands only Situation after the carousel
  settles. Entering Spatial or Dashboard resets all their clinical sections to
  expanded. Basic Information remains visible independently of disclosure.
- Basic Information remains permanently visible separately from the carousel.
- Retain all three reference Orbit navigation controls: a draggable ring,
  Previous/Next buttons, and a position slider updated for nine cards.
  Ring and slider dragging scrub the carousel; release snaps to the nearest
  card and automatically expands it. Previous/Next moves one card and expands
  it after settling. Highlight suppression during movement follows the rule below.
- Source outlines follow card disclosure in the active presentation mode:
  - Orbit: outline only the expanded front card's source. Clear outlines while
    rotating or when the front card is collapsed; restore the applicable outline
    when snapping has completed and the front card expands.
  - Spatial: outline sources for every expanded clinical card. Multiple sources
    may be outlined simultaneously.
  - Dashboard: show no equipment source outlines.
  Cards without an equipment source produce no equipment outline.
- The user delegated occlusion behavior to implementation, preferring simplicity.
  Adopt the reference design's normal occlusion: outlines disappear behind
  covering geometry. Rendering technique remains an implementation choice and
  must be validated in the scene; feasibility is not yet established.
- Preserve the reference equipment mappings below. Situation has no equipment
  source because its combined findings do not identify one apparatus.

| Card | Equipment entity names |
| --- | --- |
| Vitals | `MachineB` (free-standing monitor) |
| Active Infusions | `InfusionPump`, `MachineF` |
| Lines & Access | `IVDrip` |
| Systems Assessment | `Ventilator` |
| Situation, Related Background, Abnormal Labs, Treatment Plan, Escalation, Basic Information | None |

Entity names are preserved from the reference. Native scene checks are recorded
in the validation section below.

## Agreed SharePlay follow-up, implementation deferred

On 9 September the user agreed to synchronization of presentation mode changes,
Orbit navigation, and individual/group card disclosure, including Dashboard
disclosure. Late joiners inherit the current state without resetting the session.
Equipment outlines are derived locally from that shared state, with no separate
highlight message. Dashboard scrolling synchronization remains a separate task.

Do not implement this SharePlay follow-up until the user explicitly says it is
time to implement it. Existing SharePlay behavior and messages remain in place.
The user subsequently authorized Orbit and source-outline implementation. That
authorization leaves this SharePlay follow-up deferred.

TODO comments mark `AppModel.presentationMode`, `AppModel.cardStates`, and
`DashboardPresentationState.expandedSections`. `OrbitController.state` carries the same deferred follow-up for local
navigation/disclosure. Conflict resolution and synchronization validation
still need to be settled before the deferred work begins.

## Reference findings

Inspected local `main` on 8 September 2026:

- `Handover_V4/SharedState/OrbitController.swift` owns navigation, snapping, and
  delayed expansion. The existing layout assumes eight authored carousel slots;
  nine-card support requires reviewing geometry and navigation together.
- `Handover_V4/Models/SourceCoupling.swift` maps Vitals to `MachineB`, Infusions
  to `InfusionPump` and `MachineF`, Lines & Access to `IVDrip`, and Systems
  Assessment to `Ventilator`. Other existing sections have no equipment source.
- `Handover_V4/View/Immersive/ImmersiveView.swift` derives highlights from the
  expanded front card in Orbit, suppressing them during rotation and when that
  card is collapsed. Outside Orbit it uses all expanded clinical cards.
- `Handover_V4/View/Immersive/SourceHighlightController.swift` currently applies
  emissive material changes, with an additive box halo fallback. Despite the
  accepted outline design in `main`'s `docs/adr/0005-selectable-source-highlight-style.md`,
  the inspected controller does not implement an outline renderer.

## Implementation

- `Presentation/Orbit/OrbitPresentationState.swift` fixes the nine-card order and
  owns pure navigation, exclusive disclosure, and source eligibility.
- `OrbitController` cancels superseded settling tasks; revision checks reject stale
  completions. Ring and slider scrubbing collapse the front card immediately.
- `OrbitGeometry` reads `OrbitAnchor` and its `OrbitSlotComponent` markers from the
  scene. `OrbitPath` samples a closed Catmull-Rom curve through those markers.
  Eight authored markers define the curve for nine cards; a ninth marker is not
  required. Slot zero stays the front reading position. Moving/rotating/scaling
  the anchor in Reality Composer Pro moves the ring and carousel together.
- `PatientInformationSlot` is used exactly as authored, independently of the
  carousel. Clinical cards sit 8 cm above the ring path, matching the reference
  offset. The prior hard-coded scene placement is only a fallback for older
  scenes without usable markers.
- `ImmersiveSceneController` discovers loaded POIs directly, mounts attachments at
  scene root, updates collision bounds during disclosure, and restores Spatial
  positions on exit. Dynamic attachments read the current patient.
- Source outlines are cyan front-culled copies of each equipment mesh, expanded
  about its own center by 6 mm per side in world scale. Original materials stay
  intact. Standard depth testing preserves scene occlusion. There is no box halo,
  equipment fill, emissive recoloring, or separate highlight message.
- Sources without resolvable meshes are logged. Rendering reuses cached shells
  and only changes visibility when the eligible equipment set changes.

## Validation

State/controller checks cover nine-card reading order, entry and re-entry,
Previous/Next wraparound, scrubbing/snapping, cancellation on exit and newer input,
front-card collapse, source mapping, no-source cards, nonfinite input, eight-marker
sampling for nine cards, and ring drag continuity across the closing seam.
The generic visionOS Simulator build and dashboard disclosure checks pass.

Native validation and remaining headset checks are recorded in
[dashboard validation](dashboard-design.md#orbit-and-source-outlines-9-september-2026).
SharePlay mode/navigation/disclosure catch-up and conflict resolution remain deferred.
