# Spatial cards

Agreed behavior, not implemented. Updated 8 September 2026.
Visual styling is pending Claude's proposal and user review. The supplied
screenshot is a reference, not an approved specification to copy in full.

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

Current Spatial code still permits dragging, supports compact Basic Information,
and lacks a Situation entry in its card mapping. The behavior above is planned.
No spatial redesign or scene changes have been made or validated in this design
session. Keep the agreed behavior as constraints for Claude's visual proposal;
wait for user review before implementing that visual redesign.
