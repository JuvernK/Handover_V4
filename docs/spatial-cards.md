# Spatial cards

Agreed behavior. Updated 8 September 2026.

Implemented on `feature/presentation-mode-switch`: SBAR badges, collapsed
badge+title cards, permanent Basic Information, the Situation POI/card, the
SBAR/ALL rail, and removal of free dragging. Visual styling (colors, spacing,
badge shape) is a first pass based on `docs/mockups/spatial-cards-design.html`,
not a final approved design — treat it as still open to change. None of this
has been verified on-device/simulator yet; visionOS debug builds need Xcode's
own debugger to launch, which wasn't available when this was implemented. See
"Current status and pending work" below.

For mode switching, shared controls, disclosure resets, future SharePlay, source
organization, and implementation prerequisites, read
[presentation-modes.md](presentation-modes.md). Terms: [CONTEXT.md](../CONTEXT.md).

## Position and disclosure

- Fix cards at authored points of interest; remove free dragging. Retain the
  existing `BillboardComponent` so each card faces its viewer. This orientation
  stays local to each participant.
- Basic Information is the permanent patient introduction in Spatial: fully
  visible, no disclosure control, and excluded from SBAR/ALL. Hide it with the
  other spatial cards in Dashboard mode.
- Give each clinical card an S/B/A/R header badge. Its header independently
  toggles disclosure. Collapsed cards retain only badge and title at their fixed
  point of interest, so they can be reopened directly.
- Put the S/B/A/R/ALL rail in the persistent control window beside the mode switch
  and Exit. A letter expands its entire group if any member is collapsed;
  otherwise it collapses that group. Other groups stay unchanged. ALL applies
  the same rule to every SBAR card, excluding Basic Information.

## Card mapping

| Tag | Cards |
| --- | --- |
| S | Situation / Working Diagnosis |
| B | Related Background |
| A | Vitals, Infusions, Lines & Access, Labs, Systems Assessment |
| R | Treatment Plan, Escalation |

Basic Information has no SBAR badge. Reuse the existing patient content; do not
create duplicate clinical records for Spatial.

## Situation point of interest

Add a fixed Situation point of interest beside Basic Information and map it to
the existing Situation content. Preserve all existing authored POI names.

The scene is editable at
`Packages/RealityKitContent/Sources/RealityKitContent/RealityKitContent.rkassets/Immersive.usda`.
Direct scene authoring can be attempted during implementation, but placement must
be visually validated.

TODO: If the Situation POI cannot be authored and validated directly, remind the
user to create it beside Basic Information in Reality Composer Pro. Supply the
exact entity name and component settings expected by the implementation.

## Current status and pending work

Implemented: `SBARGroup` model (`Handover_V4/Models/SBARGroup.swift`) with the
S/B/A/R → SectionID mapping and per-POI-name group lookup; `CardHeader` badge
parameter, wired into all nine relevant cards (Vitals, Infusions, Lines & Access,
Labs, Systems Assessment, Plan, Escalation, Related Background, Situation);
`SpatialCardView` always renders Basic Information fully, adds a Situation
branch, and shows badge+title on collapse; `ImmersiveView`'s drag gesture is
removed; `AppModel.toggleSBARGroup`/`toggleAllSpatialCards` and the SBAR rail
in `LauncherView`, shown only in Spatial mode.

The Situation POI now exists in `Immersive.usda` (authored by the user).

Still pending: on-device/simulator visual verification (see note above), and
this doc's own "not implemented" framing throughout `presentation-modes.md`'s
prerequisites — Orbit still hasn't landed, so this went in ahead of that
prerequisite at the user's explicit request, same as the mode switch itself.
