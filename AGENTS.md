# AGENTS.md

Canonical guidance for Codex and other coding agents working in this
repository.

Do not preserve backward compatibility. Remove obsolete paths instead of adding compatibility layers, fallbacks, or migrations.
Choose the simplest implementation that fully meets the current requirements. Avoid speculative abstractions, configuration, and indirection.
Grow the system in layers. Start from the smallest version that works end to end, and add each new capability on top of a product that already works. Never trade a working product for unfinished complexity.
Keep components modular and concerns clearly separated.
Prefer established, well-maintained libraries when they reduce overall complexity or improve reliability. Do not reimplement common functionality without a clear reason.
Lean on the dependencies already in the project before writing your own implementation or adding packages. Do not assume a library lacks a capability without checking its documentation and types.
Fix the actual cause of a problem, not its symptoms. Do not hack around an issue to make it appear solved, and do not leave a known-broken path in place with a comment saying it'll be fixed later.
Before declaring a task complete, verify it: run the tests, run the build, or actually execute the code path you changed. Do not report something as done based on the diff looking correct.
Touch only the code required for the task at hand. Do not refactor, rename, or "clean up" unrelated code in the same change.
If a requirement is ambiguous or underspecified in a way that would change the design, ask before building. Do not guess silently and produce something that has to be redone.



## Project

Read `CONTEXT.md` first. It is the canonical source for project-specific domain
language; do not redefine its terms in agent instructions or implementation
documentation. Use `PROJECT_OVERVIEW.md` for the current implementation map and
`docs/adr/` for durable architectural decisions.

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
