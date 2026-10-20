# Orbit and source outlines

This document records the behavior and the separately deferred SharePlay work.
Related plans: [presentation modes](presentation-modes.md) and
[Spatial cards](spatial-cards.md). Domain terms live in [CONTEXT.md](../CONTEXT.md).

## Requested scope
Equipment highlighting must use outlines only.

## Confirmed decisions
- Source outlines follow card disclosure in the active presentation mode:
  - Orbit: outline only the expanded front card's source. Clear outlines while
    rotating or when the front card is collapsed; restore the applicable outline
    when snapping has completed and the front card expands.
  - Dashboard: show no equipment source outlines.
  Cards without an equipment source produce no equipment outline.

| Card | Equipment entity names |
| --- | --- |
| Vitals | `MachineB` (free-standing monitor) |
| Active Infusions | `InfusionPump`, `MachineF` |
| Lines & Access | `IVDrip` |
| Systems Assessment | `Ventilator` |
| Situation, Related Background, Abnormal Labs, Treatment Plan, Escalation, Basic Information | None |

Entity names are preserved from the reference. Native scene checks are recorded
in the validation section below.
