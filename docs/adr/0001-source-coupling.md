# Source Coupling: active-card-derived emissive highlight

## Decision

Each clinical card is coupled to exactly one **Source** — the real-world origin of its
data — modelled as a closed enum: `equipment(name)` (a named mesh in the imported ICU
USDZ), `organ(sfSymbol, anchor)` (an SF-Symbol placard on an authored body-region anchor),
or `none`. When a card becomes the **Active Card** (the Focused card in Orbit, or an
expanded card in normal mode), its Source is highlighted: equipment glows via emissive
material override in the card's own identity colour; organs show a tinted SF-Symbol placard.

The mapping lives as pure data in `Models/SourceCoupling.swift`; a
`View/Immersive/SourceHighlightController.swift` (driven by `ImmersiveView`) resolves Sources
against the loaded scene, caches original materials, and applies/restores highlights.

## Why (and the alternatives rejected)

- **Controller, not a RealityKit ECS System.** Highlighting is a discrete event on an
  occasional state change, and the codebase already drives the immersive scene through
  controller objects (`OrbitLayoutController`, `ImmersiveAttachmentConfigurator`). A custom
  `System` would introduce a new paradigm and per-frame work for no benefit. A future reader
  fluent in RealityKit's ECS would reasonably expect the "native" System approach — this is
  the deliberate no.

- **No new SharePlay message.** The trigger (`focusedCardName`, `expansionStates`) is already
  synced, so the highlight is a pure local function of existing shared state and cannot drift.
  A dedicated highlight message would be redundant state that could contradict the focus state
  — strictly worse.

- **Single Source per card (no multi-source).** One Active Card in Orbit yields one highlight;
  multi-source would reintroduce the visual clutter the feature exists to avoid. Deferred until
  a card genuinely needs it.

- **Emissive glow, with a halo fallback.** Emissive is the literal match for "the machine
  lights up," but mutating imported PBR materials at runtime is fragile (multi-submesh,
  restore complexity). If entity resolution or material mutation fails, the controller logs
  (via existing `[OrbitDebug]`) and degrades to an additive coloured halo rather than crashing.

- **Per-card identity colour, not a neutral highlight.** Each card owns a colour reused as its
  Source Highlight colour, so card and machine read as a matched pair — and so multiple
  highlights in normal mode stay legible. Palette avoids ICU alarm reds/ambers to prevent
  colliding with real alarm semantics.

## Resolved mapping

An `equipment` Source names one-or-more entities (one logical apparatus may be several meshes);
all named meshes glow together. Entity names verified in the RCP hierarchy
(`Root/ICU_env/ICUArea/…`):

| Section | Source |
|---|---|
| Vitals | `equipment` [`MachineB`] — free-standing monitor only (the Headboard-mounted monitor is fused into `Headboard` and not isolable) |
| Active Infusions | `equipment` [`InfusionPump`, `MachineF`] |
| Lines & Access | `equipment` [`IVDrip`] |
| Systems Assessment | `equipment` [`Ventilator`] |
| Abnormal Labs | `organ` `drop.fill`, anchored to `OrganAnchor_torso` (under `Root`, scale 1.0) |
| Treatment Plan / Escalation / Related Background / Basic Information | `none` |

## Status

Accepted and unblocked. Equipment names and the `OrganAnchor_torso` body anchor are authored in
RCP; implementation can proceed.
