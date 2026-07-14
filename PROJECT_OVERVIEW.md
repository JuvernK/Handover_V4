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
  - `DashboardView.swift` includes the custom wrapping card layout, drag-and-drop reordering, SharePlay controls, and immersive entry control.
  - `PatientHeaderView.swift` renders pinned patient identity/basic information.

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
