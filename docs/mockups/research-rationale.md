# Integrated dashboard design rationale

Status: historical. The user rejected all three layouts in `dashboard-options.html`
and later `dashboard-integrated.html`'s two-column board. Those drafts, and the
research below, remain as design history — see "Outcome" at the end of this file
for what was actually built and why the research below no longer describes it.

## Sources read

- Jun Yong Khor, *Investigating Situated Visualisations of EHR Data in Immersive
  Spaces for ICU Nurse Handover*, minor thesis, Semester 1 2026. Local PDF:
  `/Users/juvern/Downloads/Research/thesis_paper/32429975-JunYongKhor-JoeLiu-Thesis.pdf`.
  References below refer to Part 2's printed page numbers, not PDF page indices.
- Thomas et al., *Echo: A Large Display Interactive Visualization of ICU Data for
  Effective Care HandOffs* (2017). Local PDF:
  `/Users/juvern/Downloads/Research/thesis_paper/Echo A Large Display Interactive Visualization of ICU Data.pdf`.
  References below use the manuscript's page numbers.

## Purpose and implications

The dashboard is a shared reference for a spoken handover. It should help incoming
nurses form a patient overview, connect findings with treatment and care priorities,
and revisit precise information without reconstructing it from memory. It supplements
the EHR and nurse-to-nurse conversation (thesis §§2.1, 3.3.1, 3.3.3, 5.3).

| Evidence | Proposed design response (inference, not a validated result) |
| --- | --- |
| Thesis §3.3.1, pp. 4-5: major categories visible together, including abnormal labs, infusions and treatment priorities | Keep these categories in one expanded overview; remove tabs and record pagination from the primary handover view |
| Thesis §3.2, p. 4: ISBAR structures both narration and information | Use the existing rail to highlight and open groups in place, preserving independent disclosure |
| Thesis §3.3.3, p. 5: support participant control, disclosure and shared attention | Keep section positions stable during focus changes; retain access to independently disclosed system concerns |
| Thesis §§4.2 and 5.1, pp. 7-8: exact details and secondary tasks were vulnerable to omission | Show all authored plan items, values and units for the sample case; distinguish urgency with text as well as colour |
| Thesis §§4.4 and 5.2, pp. 8-9: readability, revisiting, comparison and handover flow matter | Place content in compact, predictable groups with no large empty card region |
| Echo §3.2.2, pp. 9-10: simple small-multiple trends, related data together, details and overlays | Keep familiar value displays and actual recorded trends; do not introduce radar plots or fabricated time-series data |
| Echo §4, p. 11: switching days made comparisons difficult; overlays addressed that problem | Avoid using view switching as the main solution to limited space |

Echo's patient-prioritisation overview serves a different task from this manually
selected, single-patient dashboard. It does not justify a patient picker here.
Its annotation and comparison features are useful references, not additions made
by this draft. No lab history, causal relationship, or new clinical conclusion is
generated from the current records.

## Evidence boundaries

The thesis reports two clinically experienced participants, different cases between
conditions, mixed workload patterns, and an unaided recall task. Both preferred the
spatial condition, but the study does not establish superiority in retention or
workload. Echo reports three naive testers and feedback from two domain collaborators;
its findings are design evidence, not proof of clinical effectiveness.

## Draft scope

- Embedded snapshot of BED-01 from `PatientData.json`; no source clinical data changed.
- Header, all five vitals, five labs, three infusions, five lines, seven plan items,
  and six system summaries are present in the expanded overview.
- Additional background, family information and main concerns open in dialogs.
- S/B/A/R opens and highlights its group without closing others. ALL toggles all
  section details; head-to-toe summaries remain visible. This preserves the main
  disclosure model but proposes starting expanded and replacing scroll-to-focus.
- Compact HTML typography is a design study, not a specification for native visionOS
  font sizes or hit areas. Small windows allow scrolling as an access fallback.
- SharePlay, annotations, rearrangement, clinical relationship highlighting, and
  immersive integration are not implemented by this HTML draft.
- No Swift changes or app build. JavaScript syntax and whitespace checks passed.
  Browser visual validation is recorded in `docs/dashboard-design.md`.

## Outcome (2026-09-08)

Neither the two-column board above nor its two-lane (40/60) successor — a later,
undocumented HTML-to-Swift port that briefly shipped on this branch — is what the
dashboard now uses. A `/grilling` session on 2026-09-08 established the current
design instead: a masonry flow board (2-3 columns, cards sized to their own
content, Assessment fixed at a 2-column span), validated as a throwaway prototype
at [dashboard-flowboard.html](dashboard-flowboard.html) before being built into
`Handover_V4/View/Dashboard/FlowBoardLayout.swift`. Full rationale and the
implemented behavior are in `docs/dashboard-design.md`.

This knowingly departs from one piece of evidence-backed guidance above: "keep
section positions stable during focus changes" (from thesis §3.3.3, informing
the "keep section positions stable" row). Masonry reflow means a card's on-screen
column can change when a sibling expands or collapses — the opposite of a stable
position. This was a deliberate, informed choice: the user was told the risk
(possible disorientation mid-handover) before choosing full reflow over a
fixed-slot alternative. It has not been evaluated against the thesis's original
concern, so this file records the trade-off rather than resolving it — the
prior evidence is not wrong, it's an open risk to weigh if real handover use
suggests the reshuffling is disorienting.
