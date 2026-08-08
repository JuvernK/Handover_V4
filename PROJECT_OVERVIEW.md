# Handover V4 Project Overview

This document maps the current implementation and its file responsibilities. It
does not define domain language: `CONTEXT.md` is the canonical glossary for
project-specific terms, and `docs/adr/` records durable architectural decisions.
Build and agent-working instructions belong in `AGENTS.md`.

## App Spine

- `Handover_V4App.swift` is the app entry point.
  - Creates the dashboard window.
  - Creates the immersive controls window.
  - Creates the full immersive space.
  - Registers `PointOfInterestComponent` and `PointOfInterestRuntimeComponent`.

- `WindowManagement/AppWindow.swift` defines stable identities for the dashboard and immersive-controls windows.
  - Both scenes use value-based `WindowGroup` declarations so repeated open requests reuse the same logical window.
  - Window transitions open and dismiss using the same scene ID and value.

- `AppModel.swift` composes app-wide feature state and provides the small API used by views.
  - Immersive space state.
  - `HandoverViewModel` for dashboard state.
  - `SharedCardState` for spatial-card state.
  - `SharedHandoverReplicator` for synchronized Shared Handover State.
  - `SharePlayCoordinator` for SharePlay lifecycle.

- `SharedState/SharedCardState.swift` owns spatial-card presentation state independently of SharePlay.
  - Expanded/collapsed state for each card.
  - 3D position for each card.
  - Zero-or-one inline clinical abbreviation selection for each card.
  - Transient synchronized orbit mode, rotation, focus, and focus expansion.
  - Applying card state without knowing how it is transported.
- `SharedState/OrbitController.swift` owns Orbit enablement, focus, snapping,
  navigation, and delayed expansion behind one intent-driven interface.
- `SharedState/SharedHandoverReplicator.swift` owns versioned Shared Handover
  State facts, disconnected replay, and the merge policy. Card expansion,
  position, Shared Abbreviation Selection, dashboard order, and Orbit use its
  transaction interface. Transient Orbit changes are coalesced behind an
  internal scheduling seam; settled state is sent immediately.

- `ViewModels/HandoverViewModel.swift` is the dashboard data source.
  - Loads patients through an injected `PatientLoading` dependency.
  - Selects the fixed Study Patient once from AppModel's initial bed number.
  - Tracks dashboard section order.
  - Exposes patient-loading failures for the dashboard empty state.
  - Applies replicated dashboard section order.

- `Data/PatientData.json` is the static ICU patient dataset.
  - Decoded by `Data/PatientDataLoader.swift`, the production implementation of `PatientLoading`.
  - Modelled by `Models/Patient.swift` and related enums.

- `Models/ClinicalTextIdentity.swift` defines the typed `ClinicalCardID` used
  from immersive POI discovery through shared state and SharePlay, plus stable
  semantic text identities for inline abbreviation fields.

## Main Folder Structure

- `Handover_V4/`
  - Main app target.

- `Handover_V4/View/Dashboard/`
  - Main dashboard UI.
  - `DashboardView.swift` composes the patient header, reorderable clinical cards, fixed Systems Assessment panel, dashboard controls, and empty state.
  - `PatientHeaderView.swift` renders pinned patient identity/basic information.
  - `DashboardFlexLayout.swift` implements the custom wrapping layout and multi-column card spans.
  - `DraggableDashboardCard.swift` adds drag-and-drop section reordering and
    routes local layout changes through the app model to
    `SharedHandoverReplicator`.
  - `DashboardControls.swift` contains the SharePlay and immersive-space controls shown in the dashboard ornament.
  - `EmptyDashboardState.swift` renders the fallback UI when no patient is selected.

- `Handover_V4/View/Cards/`
  - Clinical cards for vitals, related background, infusions, lines/access, labs, systems assessment, plan, escalation, and spatial card rendering.

- `Handover_V4/View/Immersive/`
  - `ImmersiveView.swift` coordinates the RealityKit scene, spatial attachments, gestures, and shared state updates.
  - `ImmersiveSceneLoader.swift` loads the Reality Composer Pro scene and optional ambient audio.
  - `ImmersiveAttachmentFactory.swift` creates SwiftUI card attachments for discovered points of interest.
  - `ImmersiveAttachmentConfigurator.swift` configures RealityKit attachment entities, collision shapes, and synchronized positions.
  - `AttachmentsProvider.swift` stores the SwiftUI views exposed to RealityKit as attachments.
  - `SpatialCardGestures.swift` handles whole-card 3D dragging and Orbit
    rotation. Spatial Card expansion is controlled by an explicit chevron in
    `SpatialCardView` so interactive card content owns its own selection.
  - `OrbitLayoutController.swift` builds the interactive ring and lays cards out in the focused carousel.
  - `PointOfInterestMapper.swift` resolves each authored POI name once to a
    canonical `ClinicalCardID`; unknown debug POIs remain local and are not
    synchronized.
  - `ImmersiveConfiguration.swift` contains shared scene, collision, timing, and movement constants.

- `Handover_V4/SharePlay/`
  - GroupActivities / SharePlay session code.
  - `SharePlayCoordinator.swift` manages activation and active-session
    lifecycle.
  - `SessionController.swift` is the production `ReplicationTransport` adapter:
    it manages one active group session, configures the spatial coordinator,
    and sends or receives only `ReplicationEnvelope`.
  - `ReplicationEnvelope` is the only message observed or sent by the session
    transport.

- `Packages/RealityKitContent/`
  - Local Swift package containing RealityKit / Reality Composer Pro content.
  - Includes the `Immersive` scene asset and the design-time `PointOfInterestComponent`.

## Dashboard Implementation

`Models/SectionID.swift` defines the implemented dashboard sections and maps
each section to its card view. Refer to `CONTEXT.md` for the meaning of
project-specific card terminology.

Default order:

```swift
[.vitals, .relatedBackground, .infusions, .lines, .labs, .systems, .plan, .escalation]
```

The Systems Assessment card is special in `DashboardView`: it is kept in a fixed right-side panel and excluded from the reorderable wrapped card layout.

### Dashboard Responsibilities

- `DashboardView` owns screen-level composition and calculates the widths of the main card area and fixed Systems Assessment panel.
- `DashboardFlexLayout` measures and positions the reorderable cards. The Vitals card spans two columns when enough space is available; other cards occupy one column.
- `DraggableDashboardCard` is both the drag source and drop target for a section. Dropping one section onto another moves it into the destination section's current position.
- `DashboardControls` starts or ends SharePlay and provides entry to the immersive space.
- `HandoverViewModel.sectionOrder` remains the source of truth for dashboard
  ordering. `SharedHandoverReplicator` synchronizes reorder operations with
  other participants. The Study Patient is chosen only by AppModel's initial
  bed number and is not a runtime or synchronized value.

## Immersive Implementation

### POI mapping

Reality Composer Pro POI names are normalized by lowercasing and replacing spaces/hyphens with underscores.

Known mappings:

- `basic_information` renders the patient header / compact basic information card.
- Section POIs should match `SectionID.rawValue`, such as:
  - `vitals`
  - `related_background`
  - `infusions`
  - `lines`
  - `labs`
  - `systems`
  - `plan`
  - `escalation`

If a POI name does not match, `SpatialCardView` renders an unknown POI debug card.

### Reality Composer Pro Orbit authoring

Use the canonical `CONTEXT.md` definitions for Orbit and Focused Card. The
runtime implementation keeps Patient Information stationary while the eight
clinical cards rotate; starting a rotation collapses the focused card, and
releasing snaps and expands the card at the front.

The Reality Composer Pro hierarchy is:

```text
Root
├── ICU_env                 scale 0.01
└── OrbitAnchor             scale 1.0
    ├── PatientInformationSlot
    ├── OrbitSlot_0         front reading position
    ├── OrbitSlot_1
    ├── OrbitSlot_2
    ├── OrbitSlot_3
    ├── OrbitSlot_4
    ├── OrbitSlot_5
    ├── OrbitSlot_6
    └── OrbitSlot_7
```

- Keep `OrbitAnchor` outside `ICU_env` and at scale `1`; otherwise it inherits
  the ICU asset's `0.01` scale.
- Slots run clockwise from `OrbitSlot_0` when viewed from above. Their authored
  world positions are preserved at runtime by `OrbitSlotComponent`.
- `PatientInformationSlot` controls the central Basic Information card.
- `OrbitLayoutController` builds a smooth closed Catmull–Rom path through the
  eight slots. The visible ring consists of 64 procedural cylinder segments,
  each with a larger collision box for gaze-and-pinch targeting.
- Dragging the ring or a card rotates all eight cards along the path. The
  Previous/Next controls perform the same slot transition.

The Orbit size is determined by the slot positions, not a radius setting. To
make it smaller, keep `OrbitAnchor` at scale `1` and reduce every slot's local
X/Z distance from the anchor while leaving Y unchanged. For a circular orbit
with radius `r`, use:

```text
OrbitSlot_0: ( 0.000r, Y,  1.000r)
OrbitSlot_1: (-0.707r, Y,  0.707r)
OrbitSlot_2: (-1.000r, Y,  0.000r)
OrbitSlot_3: (-0.707r, Y, -0.707r)
OrbitSlot_4: ( 0.000r, Y, -1.000r)
OrbitSlot_5: ( 0.707r, Y, -0.707r)
OrbitSlot_6: ( 1.000r, Y,  0.000r)
OrbitSlot_7: ( 0.707r, Y,  0.707r)
```

Debug builds emit `[OrbitDebug]` messages for slot discovery, attachment
registration, Orbit state changes, and calculated card targets.

## Shared Handover State Implementation

`CONTEXT.md` defines Shared Handover State. Its implementation is centered in
`SharedHandoverReplicator`; SharePlay is one transport adapter.

- Ownership:
  - `SharedCardState` owns spatial-card values without depending on GroupActivities.
  - `HandoverViewModel` owns the fixed Study Patient and dashboard-order value.
  - `SharedHandoverReplicator` owns versioning and convergence for card
    expansion, position, Shared Abbreviation Selection, dashboard order, and
    atomic Orbit facts.
  - `SharePlayCoordinator` owns SharePlay lifecycle, not domain transitions.
  - `SessionController` adapts one concrete `GroupSession` to the domain-blind
    `ReplicationTransport` interface.

- Dashboard sync:
  - Dashboard section order. The fixed Study Patient is excluded.

- Spatial card sync:
  - Expanded/collapsed state.
  - 3D card position.
  - Expansion, 3D position, and Shared Abbreviation Selection are independently
    versioned facts keyed by `ClinicalCardID`.
  - Orbit activation, rotation, focused card, and transient focus expansion as
    one atomic fact.
  - Card state and messages are keyed by `ClinicalCardID`, so authored Reality
    Composer Pro names never cross the synchronization seam.

- Conflict handling:
  - Replicated facts compare their version first, then participant ID as a
    deterministic tiebreaker.

- Late joiners:
  - `ReplicationEnvelope` sends current facts through the same merge path used
    for live changes; there is no separate catch-up message or merge policy.

## Useful Gotchas

- `Patient.lengthOfStay` currently uses `Patient.demoReferenceDate`, not the live current date, so demo ICU day values remain stable.
- `ContentView.swift` is minimal; the real first-class UI is `DashboardView`.
- `ToggleImmersiveSpaceButton.swift` handles opening/closing the immersive space and swaps between the dashboard and controls windows.
- Dashboard and controls windows use stable `AppWindow` values; ID-only `openWindow` calls would create additional `WindowGroup` instances.
- `ImmersiveView` adds SwiftUI attachments to the root RealityView content so they avoid inherited scene scaling.
- Spatial card collision shapes are regenerated from rendered attachment
  bounds after card expand/collapse or inline-abbreviation reflow because the
  SwiftUI attachment size changes.
- The project currently targets visionOS through the Xcode project and uses the local `RealityKitContent` package.
