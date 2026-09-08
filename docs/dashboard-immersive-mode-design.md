# Dashboard / Immersive Mode Design (draft, not yet implemented)

Grilled out on 2026-09-08. **Not built yet** — waiting on `latest-prototype` branch
to catch up (it doesn't have orbit yet). Implement only when explicitly asked.

## The idea

Turn today's binary "spatial vs controls" split into three modes, so they can be
tested against each other in a user study:

- **Spatial** — floating cards anchored to points on the patient/room (today's
  default, no orbit).
- **Orbit** — today's rotating carousel of cards.
- **Dashboard** — the flat 2D `DashboardView` window. Only ever shows while the
  user is inside the immersive space (`appModel.immersiveSpaceState == .open`) —
  never as a standalone window outside it.

## Decisions

1. **One 3-way switch**, not layered toggles. A segmented control
   (`Spatial | Orbit | Dashboard`) in `ImmersiveControlsView` replaces the
   current "Start/End Orbit" button. Choosing one always turns the other two
   off.
2. **Participant-visible**, freely switchable — not hidden or researcher-only.
3. **Default on entering immersive space: Spatial** (matches current behavior).
4. **Dashboard mode hides only the cards + orbit ring**, not the whole scene —
   the ICU room stays visible behind the dashboard as backdrop.
5. **New state type**: `PresentationMode { spatial, orbit, dashboard }` as its
   own thing, not stuffed into the existing `OrbitState`/`CardInteractionMode`
   (that state carries orbit-only fields like `rotation` and
   `focusedCardName` that don't apply to dashboard mode).
6. **Sync**: reuse the existing SharePlay fact-replication pattern in
   `Handover_V4/SharedState/SharedHandoverReplicator.swift` (same way `.orbit`
   is replicated today) — add a `presentationMode` fact. Since opening/closing
   the dashboard window is a per-device action (not RealityKit state), each
   participant's app reacts to the synced mode locally with
   `openWindow`/`dismissWindow`.

## Still open

- Whether the Orbit sub-controls (prev/next buttons) show disabled or fully
  hidden when the mode isn't Orbit. Grilling paused here when the branch
  situation came up.

## Why

Testing all three presentation styles against real users in a headset study,
synced so every participant in a session sees the same condition at once.
