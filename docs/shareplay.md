# SharePlay

Implemented on `feature/shareplay-snapshot`, 26 October 2026. The design decision
is [ADR 0006](adr/0006-shareplay-snapshot-sync.md). Product terms are in
[CONTEXT.md](../CONTEXT.md).

## Behavior

The study setup is several Vision Pro wearers in the same room, using visionOS 26
nearby sharing. Every participant sees the same handover:

| Shared | Stays on each device |
| --- | --- |
| ICU immersive space open or closed | Head pose, gaze, viewer-facing card orientation |
| Presentation mode | Personal window placement |
| Orbit card the carousel is on or heading to, and whether it is expanded | An Orbit drag before release |
| Spatial card expanded or collapsed | Dashboard free scrolling (window sizes differ) |
| Dashboard section disclosure, SBAR focus and section order | Light or dark appearance |

- Anyone can change anything. When two people change something at the same
  moment, the later version wins everywhere (see conflicts below).
- Entering or exiting the ICU moves everyone. Closing the space from outside the
  app also counts as exiting. If the space fails to open on one device, that
  device stays out without closing it for the others; its Enter button retries.
- A mode change carries its reset (Spatial and Dashboard fully expanded, Orbit on
  Situation), so peers receive the result instead of each resetting.
- Orbit is shared when a card is chosen: Previous/Next, the slider or a ring
  release start everyone's carousel moving together. A drag in progress is local.
- Following a peer's SBAR navigation scrolls the dashboard to that section.
- Late joiners take the group's current state and never reset anyone. They also
  open the ICU if the group is in it.
- **Leave SharePlay** in the launcher removes only this device. There is no
  "end for everyone" button.
- SharePlay starts from **Start SharePlay** in the launcher or from the window's
  system Share menu. Outside a FaceTime call, visionOS offers nearby sharing.

## How it works

One `SharedHandoverSnapshot` holds every shared fact. Any change to it is sent
whole as a `SharedHandoverMessage` over one reliable `GroupSessionMessenger`.
The same message brings late joiners up to date.

- `AppModel` owns the state. `AppModel.currentSnapshot` reads it, and an
  `Observations` loop sends a message whenever the snapshot changes, so views
  change state normally with no SharePlay code. `AppModel.receive(_:)` applies a
  peer's snapshot through the same properties.
- `SharedHandoverReplica` decides what to send and what to apply. A received
  snapshot becomes the shared value, so applying it never echoes back.
- `SharedHandoverVersion` orders snapshots: change count first, then the earlier
  session join, then participant ID. Equal counts mean a late joiner adopts the
  group's state. The join-time rule relies on device clocks agreeing to within
  the seconds between joins.
- `SessionController` sets `supportsGroupImmersiveSpace` and the `.sideBySide`
  template, starts listening, then joins. It sends the current snapshot to each
  arriving participant.
- `OrbitPresentationState.target` is what Orbit shares; `adopt(_:)` follows a
  peer's target, including a collapsed front card.
- `ToggleImmersiveSpaceButton` opens or dismisses the space to match the shared
  `AppModel.wantsImmersion`, whether the request was local or from a peer.
- The dashboard window has `.groupActivityAssociation(.primary("dashboard"))`,
  and a hidden `ShareLink` in the launcher exposes the activity in the Share menu.
- `Handover_V4.entitlements` grants `com.apple.developer.group-session`, and
  `Info.plist` sets `NSSupportsGroupActivities`. A paid development team is required.

### Conflicts

Two changes made at the same moment are whole snapshots, so the later version
replaces the earlier one, even when they touched different things (for example
one person collapses a Spatial card while another switches mode). Both devices
still end up identical. This was accepted for a study where people mostly take
turns presenting.

## Validation

Checks run on 26 October 2026:

- `sh Tests/run-checks.sh`: all five standalone checks pass, including
  `Tests/SharedHandoverReplicaChecks.swift` (late join, simultaneous changes,
  echo suppression, leaving, every fact surviving encoding, and Orbit adoption).
- The visionOS build from `AGENTS.md` succeeds with no new warnings.
- A visionOS 26.2 simulator signed build embeds the group-session entitlement.
  On it, the launcher shows Start SharePlay, and Enter ICU opens the immersive
  space and dashboard through the shared-intent path.

Not yet verified:

- Mode switching and Spatial/Dashboard/Orbit interactions after this refactor,
  in the simulator or on device. Automated simulator clicks were stopped because
  they took over the user's mouse.
- Anything with two participants. The simulator cannot join a second participant
  to a SharePlay activity, so this needs two Vision Pros.
- Whether nearby participants see the ICU and the shared dashboard window in the
  same physical place.

### Two-device test

On two Vision Pros signed into different Apple Accounts, in the same room:

1. Install the same build on both and open the app.
2. On device A, tap Start SharePlay and choose the nearby person in the Share menu.
   Device B accepts.
3. On A, enter the ICU. B enters too.
4. Switch modes on A, then on B. Each switch shows on the other, with its reset.
5. In Orbit, use Next, the slider and a ring drag on each device. The other follows
   on release. Tap the front card to collapse it; the other collapses.
6. In Spatial, toggle a card and an SBAR group. In Dashboard, collapse a section,
   use the SBAR rail and drag a section to reorder. Each appears on the other.
7. On B, tap Leave SharePlay, change the mode on A, then have B rejoin from the
   Share menu. B takes A's current state without changing A.
8. On A, exit the ICU. B exits too.
