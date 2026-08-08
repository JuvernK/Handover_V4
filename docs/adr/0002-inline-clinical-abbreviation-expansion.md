# Inline clinical abbreviation expansion

## Context

Clinical handover cards contain abbreviations that can increase a clinician's mental effort when the exact term is not immediately recalled. The existing `ClinicalAbbreviationText` detects approved glossary terms and presents their full term with a SwiftUI `.popover`. That presentation works through a transient presentation layer and has been reported not to appear when the same SwiftUI view is rendered as a RealityKit attachment in immersive space.

The feature must behave consistently in dashboard and immersive cards, preserve the established glossary, avoid adding visual clutter, and participate in the app's existing SharePlay collaboration model.

The associated user study evaluates cognitive load with NASA-TLX, usability and interaction design, and clinical plausibility with clinicians who have relevant handover experience. The exact clinical-plausibility questionnaire is not decided by this ADR.

## Decision

Replace the tooltip/popover presentation with selectable **Inline Expansion** in both dashboard and immersive cards. Preserve the existing glossary definitions and matching logic; remove only the `.popover` presentation and its tooltip-specific state and view.

Selecting an Approved Abbreviation changes:

```text
Commenced CRRT overnight
```

to:

```text
Commenced CRRT (continuous renal replacement therapy) overnight
```

The original abbreviation remains visible. Its full term uses the normal text colour and a lighter visual weight so it reads as part of the sentence rather than as another control. Selecting the abbreviation again collapses it. Selecting a different abbreviation in the same card replaces the existing selection.

### Interaction and presentation rules

- Only the selected Abbreviation Occurrence expands.
- Each card has zero or one Abbreviation Selection.
- Selectable abbreviations use an accent colour, underline, and visionOS hover feedback. The interaction must not be communicated by colour alone.
- The complete expansion is shown and may wrap. It is never truncated.
- Glossary notes are not displayed inline; this feature expands terminology rather than teaching additional clinical concepts.
- Expansion and collapse use a short reflow animation that respects Reduce Motion. Remote SharePlay changes use the same presentation.
- When an immersive attachment changes size, its collision shape is regenerated after layout settles.
- Selecting the same occurrence, selecting another occurrence, collapsing the card, or changing patient clears/replaces state according to the rules above.
- Dashboard-to-immersive persistence is not required for the current study because each study condition evaluates one UI at a time.

### Glossary safety rules

- Only Approved Abbreviations are interactive.
- The matcher must not infer the meaning of an unknown or contextually ambiguous term from surrounding prose.
- Ambiguous terms remain ordinary text until one intended meaning is explicitly approved for the app's handover data.
- Common vital-sign labels already excluded by the glossary—HR, RR, MAP, SpO2 variants, temperature, and blood pressure—remain non-interactive.

### Stable occurrence identity

SharePlay peers must identify the exact same occurrence without sending or comparing view-local state. The minimum synchronized value is:

```swift
struct AbbreviationSelection: Codable, Hashable {
    let textID: String
    let glossaryEntryID: String
    let occurrenceIndex: Int
}
```

The owning dictionary is keyed by canonical typed card identity:

```swift
var abbreviationSelections: [ClinicalCardID: AbbreviationSelection]
```

`textID` is a stable semantic identifier supplied by the card/field, such as a model field or model-item identity. It must not be derived from a random UUID, Swift's `hashValue`, the current view order, or translated/displayed text. `occurrenceIndex` is assigned in deterministic source-text order among matches for the same glossary entry in that field.

Keeping `ClinicalCardID` as the dictionary key makes
`AbbreviationSelection` the smallest robust identity while enforcing the
zero-or-one selection invariant per card. Authored POI names are resolved to
that identity before shared state or SharePlay handles the selection.

### State ownership and SharePlay

Abbreviation selection is presentation state, not glossary data and not view-local state. It belongs beside the other shared card values in `SharedCardState`; `ClinicalAbbreviationText` renders that state but does not own an independent `@State` selection.

`AppModel` exposes a small select/toggle interface. Shared Abbreviation
Selection converges as a versioned fact through `SharedHandoverReplicator`.
The former dedicated message, counter, disconnected replay, and catch-up path
have been removed; live, reconnect, and late-join delivery all use the same
envelope merge while remaining independently ordered from other facts.

Any participant may select or collapse an abbreviation. For concurrent abbreviation actions on the same card, the existing counter-plus-participant-tiebreak ordering provides deterministic last-action-wins behavior. Current selections and their update counts are included in `CatchUpMessage`, so a late joiner renders the same state.

Card collapse dominates abbreviation selection:

- Applying a local or remote collapse clears that card's selection.
- An abbreviation selection received while its card is collapsed is ignored.
- Catch-up state must not contain a selection for a collapsed card.

Changing patient clears every abbreviation selection. If runtime patient switching and in-flight messages are supported later, the message envelope must identify the patient/handover so a delayed selection from the previous patient can be rejected. The current prototype selects its initial patient in `AppModel`, so this is a future-facing safety invariant.

### Gesture ownership

The current immersive `SpatialTapGesture` treats the entire attachment entity as the card expand/collapse target. That conflicts with interactive abbreviation text.

Card expand/collapse moves to an explicit header/chevron control. Controls inside the card body, including Approved Abbreviations, own their tap/select interaction. Whole-card dragging remains available through the existing movement gesture and its minimum-distance threshold; this ADR does not introduce a small drag handle.

## Implementation seams

The intended change is constrained to these seams:

1. Retain `ClinicalAbbreviationGlossary` definitions and deterministic matching in `ClinicalAbbreviationText.swift`.
2. Replace tooltip-specific `selectedEntry`, `.popover`, and `ClinicalAbbreviationPopover` with rendering driven by the card's shared Abbreviation Selection.
3. Give every `ClinicalAbbreviationText` call site a stable card identity and semantic `textID`.
4. Add abbreviation selections and reducer-style set/clear operations to `SharedCardState`.
5. Expose selection through `AppModel`.
6. Add local broadcast, remote apply, deterministic conflict handling, and late-join catch-up through the SharePlay coordinator and message types.
7. Clear selection as part of card collapse and patient change.
8. Remove whole-entity card tap-to-toggle in immersive space and route expand/collapse through the card header/chevron.
9. Observe abbreviation-selection changes in `ImmersiveView` and regenerate attachment collision shapes after animated reflow.

## Invariants

- A card has at most one expanded Abbreviation Occurrence.
- A collapsed card has no Abbreviation Selection.
- Every displayed expansion resolves to an Approved Abbreviation.
- The app never guesses an ambiguous or unknown expansion.
- The source abbreviation remains visible beside its expansion.
- The same source data and synchronized selection produce the same expanded occurrence on every participant's device.
- Tooltip/popover presentation is not retained as a fallback.
- Whole-card dragging remains available in immersive space.

## Alternatives rejected

- **Keep the popover in dashboard and use inline expansion only in immersive space.** Rejected because the same concept would have two interaction models and the immersive presentation-boundary failure would remain encoded as a special case.
- **Delete the existing abbreviation feature completely.** Rejected because its curated glossary and matching logic are still required. Only tooltip presentation is replaced.
- **Expand every occurrence of the same abbreviation.** Rejected because the user asked for one selected occurrence and global expansion would add clutter.
- **Allow several expansions per card.** Rejected because reflow and cognitive clutter would accumulate.
- **Replace the abbreviation with only the full term.** Rejected because preserving both maintains the source wording and teaches the abbreviation.
- **Show glossary notes inline.** Rejected because notes exceed the feature's terminology-expansion purpose and may increase cognitive load.
- **Keep selection local during SharePlay.** Rejected because the shared handover should let every participant see and control the same expansion.
- **Presenter-only control.** Rejected because any participant must be allowed to request clarification.
- **Use runtime UUIDs or source-string hashes as occurrence identity.** Rejected because they are not stable semantic identities across participants and content revisions.
- **Continue whole-card tap-to-toggle.** Rejected because it competes with interactive content inside the card.

## Verification criteria

Implementation is complete only when:

1. Selecting each approved term expands the correct occurrence inline in dashboard and immersive cards.
2. Repeated appearances of the same term can be selected independently.
3. Selecting another term in the same card replaces the previous expansion.
4. Selecting the expanded term again, collapsing its card, or changing patient clears it.
5. Unknown, ambiguous/unapproved, and excluded vital-sign terms remain ordinary text.
6. Long expansions wrap without truncation and immersive collision/drag bounds follow the resized card.
7. Abbreviation selection does not toggle the card; header/chevron toggle and whole-card drag still work.
8. Two SharePlay peers converge on the same selected occurrence under simultaneous actions.
9. A late joiner receives the current selections.
10. No `.popover` abbreviation presentation remains.
11. Reduce Motion is respected and accessibility does not rely on colour alone.

## Status

Accepted design; documentation complete. Application implementation is intentionally deferred.
