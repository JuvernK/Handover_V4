# Handover V4

visionOS ICU handover prototype: a dashboard and a fully immersive ICU scene in which clinical cards orbit the patient bed. This glossary defines terms specific to the handover domain and the immersive experience.

## Immersive Cards

**Spatial Card**:
A floating SwiftUI clinical card shown in the immersive ICU scene (e.g. Vitals, Labs, Infusions), anchored to an authored point of interest.

**Orbit**:
The eight-card snapping carousel that rotates the clinical cards around the patient bed. One card occupies the front reading position at a time.

**Focused Card**:
The single card currently in the front reading position of the Orbit. Tracked by `OrbitState.focusedCardName` and SharePlay-synced.

**Active Card**:
A card the user is currently attending to, and therefore the trigger for a Source Highlight. In Orbit this is the Focused Card (exactly one); in normal mode it is each expanded card (zero-to-many). During an Orbit rotation, highlighting is suppressed until the carousel snaps.

## Source Coupling

**Source**:
The real-world origin of a card's clinical data. Exactly one per card. A Source is one of a closed set of kinds: an `equipment` entity (a named mesh in the ICU scene, e.g. the vitals monitor, highlighted by emissive glow), an `organ` (a body region shown as an SF Symbol placard — e.g. `heart`, `lungs` — tinted the Card Identity Colour and anchored to an authored body-region point on the patient, degrading to a single torso anchor), or `none` (no physical origin).
_Avoid_: link, connection (reserved for future drawn connectors, which we are deliberately not building yet).

**Source Coupling**:
The relationship binding a card to its Source. The mapping from card/section to Source lives in one place and is the feature being added.

**Source Highlight**:
The visual emphasis applied to a card's Source when that card becomes an Active Card. For `equipment`, an emissive glow on the mesh; the glow colour is the card's own Card Identity Colour (not a neutral shared colour), so the card and its Source read as a matched pair. A colour highlight, not a drawn connector.

**Card Identity Colour**:
A distinct colour assigned to each card, applied to its border/text and reused as its Source Highlight colour. Constrained to hues that avoid ICU alarm semantics (reserved reds/ambers).

## Clinical Abbreviation Expansion

**Approved Abbreviation**:
A clinical abbreviation whose single intended meaning has been explicitly entered in the app's glossary. Only Approved Abbreviations are interactive. Unknown or contextually ambiguous terms are left as ordinary text; the app never guesses an expansion. Familiar vital-sign labels such as HR, RR, MAP, SpO2, temperature, and blood pressure are deliberately excluded to keep the interface quiet.

**Abbreviation Occurrence**:
One specific appearance of an Approved Abbreviation in a clinical text field. An occurrence is identified deterministically by a stable semantic `textID`, the glossary entry ID, and its zero-based occurrence index within that text. The identity must not depend on a runtime UUID, view position, or Swift hash value because every SharePlay participant must resolve it to the same text.

**Inline Expansion**:
The full clinical term appended to an Abbreviation Occurrence in place, for example `CRRT (continuous renal replacement therapy)`. The original abbreviation remains visible. The full term may wrap and resize its card; it is never truncated. Optional glossary notes are not shown.

**Abbreviation Selection**:
The zero-or-one Abbreviation Occurrence currently expanded within a card. Selecting the same occurrence clears the selection; selecting another replaces it. A selection is cleared when its card collapses or the patient changes.

**Shared Abbreviation Selection**:
An Abbreviation Selection synchronized through SharePlay. Any participant may change it, the last accepted abbreviation action for that card wins, and late joiners receive the current selections. A collapsed card cannot accept a selection, so collapse always clears or rejects hidden abbreviation state.
