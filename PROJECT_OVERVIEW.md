# Handover V4 Project Overview

This project is a visionOS SwiftUI + RealityKit ICU handover prototype. It presents structured patient handover information in a dashboard window and can open a full immersive ICU scene with floating spatial cards anchored to Reality Composer Pro points of interest.

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
  - `SharePlayCoordinator` for synchronized updates.

- `SharedState/SharedCardState.swift` owns spatial-card presentation state independently of SharePlay.
  - Expanded/collapsed state for each card.
  - 3D position for each card.
  - Applying and replacing card state without knowing how it is transported.

- `ViewModels/HandoverViewModel.swift` is the dashboard data source.
  - Loads patients through an injected `PatientLoading` dependency.
  - Tracks the selected patient.
  - Tracks dashboard section order.
  - Exposes patient-loading failures for the dashboard empty state.
  - Applies remote dashboard state from SharePlay.

- `Data/PatientData.json` is the static ICU patient dataset.
  - Decoded by `Data/PatientDataLoader.swift`, the production implementation of `PatientLoading`.
  - Modelled by `Models/Patient.swift` and related enums.

## Main Folder Structure

- `Handover_V4/`
  - Main app target.

- `Handover_V4/View/Dashboard/`
  - Main dashboard UI.
  - `DashboardView.swift` composes the patient header, reorderable clinical cards, fixed Systems Assessment panel, dashboard controls, and empty state.
  - `PatientHeaderView.swift` renders pinned patient identity/basic information.
  - `DashboardFlexLayout.swift` implements the custom wrapping layout and multi-column card spans.
  - `DraggableDashboardCard.swift` adds drag-and-drop section reordering and routes local layout changes through the app model to `SharePlayCoordinator`.
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
  - `SpatialCardGestures.swift` handles tap-to-expand and 3D card dragging.
  - `PointOfInterestMapper.swift` normalizes authored POI names and maps them to dashboard sections.
  - `ImmersiveConfiguration.swift` contains shared scene, collision, timing, and movement constants.

- `Handover_V4/SharePlay/`
  - GroupActivities / SharePlay session code.
  - `SharePlayCoordinator.swift` manages activation, active-session lifecycle, update counters, local broadcasts, remote state application, and late-join snapshots.
  - `SessionController.swift` manages one active group session, configures the spatial coordinator, observes messages, and provides message transport.
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
- `HandoverViewModel.sectionOrder` remains the source of truth for dashboard ordering. `SharePlayCoordinator` synchronizes reorder operations with other participants.

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

SharePlay sync is centered in `SharePlayCoordinator` and `SessionController`.

- Ownership:
  - `SharedCardState` owns spatial-card values without depending on GroupActivities.
  - `HandoverViewModel` owns selected-patient and dashboard-order values.
  - `SharePlayCoordinator` owns synchronization metadata and applies local or remote changes to those state objects.
  - `SessionController` transports messages for one concrete `GroupSession`.

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
- Dashboard and controls windows use stable `AppWindow` values; ID-only `openWindow` calls would create additional `WindowGroup` instances.
- `ImmersiveView` adds SwiftUI attachments to the root RealityView content so they avoid inherited scene scaling.
- Spatial card collision shapes are regenerated after expand/collapse because the SwiftUI attachment size changes.
- The project currently targets visionOS through the Xcode project and uses the local `RealityKitContent` package.
