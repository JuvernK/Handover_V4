# AGENTS.md

Canonical guidance for Codex and other coding agents working in this
repository.

## Project

Handover V4 is a visionOS SwiftUI + RealityKit ICU handover prototype. A
dashboard window presents structured patient handover information; an immersive
space opens a full ICU scene with floating Spatial Cards anchored to Reality
Composer Pro points of interest. Sessions can be synchronized across
participants through SharePlay.

- Target platform: visionOS (`xros`, `xrsimulator`)
- Deployment target: visionOS 26.2
- Language: Swift 5
- Bundle ID: `com.monash.Handover-V4`
- Swift Testing unit tests live in the `Handover_V4Tests` target

## Build and run

Open `Handover_V4.xcodeproj` in Xcode and run against the Apple Vision Pro
simulator, or build from the command line:

```bash
xcodebuild -project Handover_V4.xcodeproj -scheme Handover_V4 \
  -destination 'platform=visionOS Simulator,name=Apple Vision Pro' build
```

`xcodebuild -list` and simulator commands can be slow or hang. Prefer Xcode for
interactive verification.

## Architecture

Read `PROJECT_OVERVIEW.md` before making architectural changes. It documents
the app spine, folder responsibilities, dashboard sections, immersive POI and
Orbit authoring, and SharePlay synchronization in detail.

- **App composition:** `AppModel` owns the small API exposed to views and
  composes immersive-space state, `HandoverViewModel`, `SharedCardState`, and
  `SharePlayCoordinator`.
- **State and transport:** `SharedCardState` owns Spatial Card expansion, 3D
  position, and Orbit values. `HandoverViewModel` owns selected-patient and
  dashboard-order values. Neither depends on `GroupActivities`.
  `SharePlayCoordinator` applies local and remote changes; `SessionController`
  transports messages for one `GroupSession`.
- **Synchronized state:** when adding a synchronized value, update its owning
  state object and the message types, then handle local broadcast, remote
  application, and late-join `CatchUpMessage`.
- **Dashboard:** `DashboardView` composes the pinned patient header, the
  reorderable wrapped layout implemented by `DashboardFlexLayout` and
  `DraggableDashboardCard`, and the fixed Systems Assessment panel, which is
  excluded from reordering. `HandoverViewModel.sectionOrder` is the ordering
  source of truth.
- **Immersive space:** `ImmersiveView` coordinates the RealityKit scene,
  attachments, and gestures. `PointOfInterestMapper` normalizes POI names by
  lowercasing them and replacing spaces or hyphens with underscores before
  mapping them to `SectionID.rawValue`; unmatched POIs render a debug card.
  `OrbitLayoutController` implements the eight-slot snapping carousel. Shared
  scene, collision, and timing constants belong in `ImmersiveConfiguration`.
- **Windows:** dashboard and immersive-control scenes use value-based
  `WindowGroup`s with stable `AppWindow` identities. Use the `AppWindow` value
  when opening a window so requests reuse the same logical instance. ID-only
  `openWindow` calls create additional `WindowGroup` instances.
- **Data:** `Data/PatientData.json` is decoded by the production
  `PatientDataLoader` implementation of `PatientLoading` into
  `Models/Patient.swift`. `HandoverViewModel` receives the loading dependency
  through injection.

## Conventions and visionOS constraints

- Dashboard sections are defined once in `Models/SectionID.swift`, including
  their card-view mapping. Default ordering and the special Systems Assessment
  panel are documented in `PROJECT_OVERVIEW.md`.
- `Patient.lengthOfStay` uses `Patient.demoReferenceDate` so demonstration ICU
  day values remain stable.
- Regenerate Spatial Card collision shapes after expand/collapse or another
  content change resizes a SwiftUI attachment.
- Add SwiftUI attachments to the root `RealityView` content to avoid inherited
  scene scaling.
- Debug builds emit `[OrbitDebug]` logs for slot discovery, attachment
  registration, and Orbit state.
- Register `PointOfInterestComponent` and
  `PointOfInterestRuntimeComponent` at app launch in `Handover_V4App.swift`.
- RealityKit and Reality Composer Pro content lives in the local
  `Packages/RealityKitContent` Swift package.

## Agent skills

### Issue tracker

Issues and specifications are tracked with GitHub Issues. Follow
`docs/agents/issue-tracker.md`.

### Triage labels

Use the repository's five-role triage vocabulary from
`docs/agents/triage-labels.md`.

### Domain docs

This is a single-context project. Read root `CONTEXT.md` and relevant records
under `docs/adr/` according to `docs/agents/domain.md`.
