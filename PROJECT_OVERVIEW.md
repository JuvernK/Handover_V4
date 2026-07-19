# Handover V4 Project Overview

This project is a visionOS SwiftUI + RealityKit ICU handover prototype. It presents structured patient handover information in a dashboard window and can open a full immersive ICU scene with floating spatial cards anchored to Reality Composer Pro points of interest.

## App Spine

- `Handover_V4App.swift` is the app entry point.
  - Creates the dashboard window.
  - Creates the immersive controls window.
  - Creates the full immersive space.
  - Registers `PointOfInterestComponent` and `PointOfInterestRuntimeComponent`.

- `AppModel.swift` owns app-wide state.
  - Immersive space state.
  - SharePlay lifecycle.
  - Expanded/collapsed state for spatial cards.
  - 3D card positions.
  - Dashboard section order and selected patient sync.
  - Remote SharePlay message handling and late-join catch-up state.

- `ViewModels/HandoverViewModel.swift` is the dashboard data source.
  - Loads patients from JSON.
  - Tracks the selected patient.
  - Tracks dashboard section order.
  - Applies remote dashboard state from SharePlay.

- `Data/PatientData.json` is the static ICU patient dataset.
  - Decoded by `Data/PatientDataLoader.swift`.
  - Modelled by `Models/Patient.swift` and related enums.

## Main Folder Structure

- `Handover_V4/`
  - Main app target.

- `Handover_V4/View/Dashboard/`
  - Main dashboard UI.
  - `DashboardView.swift` composes the patient header, reorderable clinical cards, fixed Systems Assessment panel, dashboard controls, and empty state.
  - `PatientHeaderView.swift` renders pinned patient identity/basic information.
  - `DashboardFlexLayout.swift` implements the custom wrapping layout and multi-column card spans.
  - `DraggableDashboardCard.swift` adds drag-and-drop section reordering and sends local layout changes through `AppModel` for SharePlay synchronization.
  - `DashboardControls.swift` contains the SharePlay and immersive-space controls shown in the dashboard ornament.
  - `EmptyDashboardState.swift` renders the fallback UI when no patient is selected.

- `Handover_V4/View/Cards/`
  - Clinical cards for vitals, related background, infusions, lines/access, labs, systems assessment, plan, escalation, and spatial card rendering.

- `Handover_V4/View/ImmersiveView.swift`
  - Loads the RealityKit `Immersive` scene.
  - Detects entities with `PointOfInterestComponent`.
  - Creates SwiftUI attachments for spatial cards.
  - Supports spatial tap to expand/collapse cards.
  - Supports drag to reposition cards in 3D.
  - Syncs card state and position through `AppModel`.

- `Handover_V4/SharePlay/`
  - GroupActivities / SharePlay session code.
  - `SessionController.swift` manages group sessions and message observation.
  - `SharePlayMessagingType.swift` defines card sync, dashboard sync, update counters, and catch-up messages.

- `Packages/RealityKitContent/`
  - Local Swift package containing RealityKit / Reality Composer Pro content.
  - Includes the `Immersive` scene asset and the design-time `PointOfInterestComponent`.

## Dashboard Sections

`Models/SectionID.swift` defines all dashboard sections and maps each section to its card view.

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
- `HandoverViewModel.sectionOrder` remains the source of truth for dashboard ordering. Reordering is routed through `AppModel` so changes can be synchronized with SharePlay participants.

## Immersive POI Mapping

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

## SharePlay Sync

SharePlay sync is centered in `AppModel` and `SessionController`.

- Dashboard sync:
  - Selected patient.
  - Dashboard section order.

- Spatial card sync:
  - Expanded/collapsed state.
  - 3D card position.

- Conflict handling:
  - `MessageUpdateCount` compares update count first, then participant ID as a deterministic tiebreaker.

- Late joiners:
  - `CatchUpMessage` sends current card states, card positions, update counts, and dashboard state.

## Useful Gotchas

- `Patient.lengthOfStay` currently uses `Patient.demoReferenceDate`, not the live current date, so demo ICU day values remain stable.
- `ContentView.swift` is minimal; the real first-class UI is `DashboardView`.
- `ToggleImmersiveSpaceButton.swift` handles opening/closing the immersive space and swaps between the dashboard and controls windows.
- `ImmersiveView` adds SwiftUI attachments to the root RealityView content so they avoid inherited scene scaling.
- Spatial card collision shapes are regenerated after expand/collapse because the SwiftUI attachment size changes.
- The project currently targets visionOS through the Xcode project and uses the local `RealityKitContent` package.
