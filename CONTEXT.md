# Handover V4

visionOS ICU handover prototype: a dashboard and a fully immersive ICU scene in which clinical cards orbit the patient bed. This glossary defines terms specific to the handover domain and the immersive experience.

## Immersive Cards

**Spatial Card**:
A floating SwiftUI clinical card shown in the immersive ICU scene (e.g. Vitals, Labs, Infusions), anchored to an authored point of interest.

**Orbit**:
The eight-card snapping carousel that rotates the clinical cards around the patient bed. One card occupies the front reading position at a time; the ring is visual rather than draggable.

**Orbit Navigation**:
The controls that move a card into the Orbit's front reading position: floating Previous and Next controls beside the Focused Card for one-step movement, and an eight-position slider for direct movement. Any participant may use either control; slider dragging scrubs the shared Orbit smoothly while the front card remains collapsed, and release snaps to the nearest card and expands it. Spatial Card dragging does not navigate the Orbit.

**Focused Card**:
The single card currently in the front reading position of the Orbit. Tracked by `OrbitState.focusedCardName` and SharePlay-synced.

**Active Card**:
A card the user is currently attending to, and therefore the trigger for a Source Highlight. In Orbit this is the Focused Card (exactly one); in normal mode it is each expanded card (zero-to-many). During an Orbit rotation, highlighting is suppressed until the carousel snaps.

**Card Home Position**:
The authored POI position where a Spatial Card starts and where the immersive-controls action **Reset Card Positions** returns it. The shared action atomically resets every Spatial Card, including Basic Information, for all participants so the layout remains usable when an individual card has been moved out of reach.

**Card Handle**:
The full-width top bar of a Spatial Card and the only card surface that can initiate card manipulation. Tapping it expands or collapses the card; pinching and moving it beyond the drag threshold cancels the tap and moves the card, while clinical content never initiates movement.

## Source Coupling

**Source**:
The real-world origin of a card's clinical data. Exactly one per card. A Source is one of a closed set of kinds: an `equipment` entity (a named mesh in the ICU scene, e.g. the vitals monitor, highlighted by emissive glow), an `organ` (a body region shown as an SF Symbol placard — e.g. `heart`, `lungs` — tinted the Card Identity Colour and anchored to an authored body-region point on the patient, degrading to a single torso anchor), or `none` (no physical origin).
_Avoid_: link, connection (reserved for future drawn connectors, which we are deliberately not building yet).

**Source Coupling**:
The relationship binding a card to its Source. The mapping from card/section to Source lives in one place and is the feature being added.

**Source Highlight**:
The visual emphasis applied to a card's Source when that card becomes an Active Card. Its participant-local Source Highlight Style changes how the emphasis is rendered without changing which Source is active; the Card Identity Colour links the card and its Source. A colour highlight, not a drawn connector.

**Source Highlight Style**:
The participant-local choice for an `equipment` Source between `outline`, which renders only the Source's outer silhouette in its Card Identity Colour without exposing internal mesh edges or colouring its surfaces and is the default, and `glow`, which applies the existing emissive treatment. The outline is not visible through occluding geometry; organ Sources retain their tinted placard representation, and the choice is not part of Shared Handover State. It persists across immersive-space re-entry during one app session and returns to `outline` on the next launch.

**Card Identity Colour**:
A distinct colour assigned to each card, applied to its border/text and reused as its Source Highlight colour. Constrained to hues that avoid ICU alarm semantics (reserved reds/ambers).

## Clinical Abbreviation Expansion

**Approved Abbreviation**:
A clinical abbreviation whose single intended meaning has been explicitly entered in the app's glossary. Only Approved Abbreviations are interactive and presented as Abbreviation Capsules; unknown or contextually ambiguous terms are left as ordinary text and the app never guesses an expansion. Familiar vital-sign labels such as HR, RR, MAP, SpO2, temperature, and blood pressure are deliberately excluded to keep the interface quiet.

**Abbreviation Capsule**:
The padded, hover-responsive inline control used for every Approved Abbreviation in dashboard and Spatial Cards. It uses the card's Card Identity Colour, with a stronger fill while selected, and provides a non-overlapping effective interaction target of at least 60 by 60 points; clinical text reflows when necessary to preserve that target.

**Abbreviation Occurrence**:
One specific appearance of an Approved Abbreviation in a clinical text field. An occurrence is identified deterministically by a stable semantic `textID`, the glossary entry ID, and its zero-based occurrence index within that text. The identity must not depend on a runtime UUID, view position, or Swift hash value because every SharePlay participant must resolve it to the same text.

**Inline Expansion**:
The full clinical term appended to an Abbreviation Occurrence in place, for example `CRRT (continuous renal replacement therapy)`. The original abbreviation remains visible. The full term may wrap and resize its card; it is never truncated. Optional glossary notes are not shown.

**Abbreviation Selection**:
The zero-or-one Abbreviation Occurrence currently expanded within a card. Selecting the same occurrence clears the selection; selecting another replaces it. A selection is cleared when its card collapses or the patient changes.

**Shared Abbreviation Selection**:
An Abbreviation Selection synchronized through SharePlay. Any participant may change it, the last accepted abbreviation action for that card wins, and late joiners receive the current selections. A collapsed card cannot accept a selection, so collapse always clears or rejects hidden abbreviation state.

## Shared Handover

**Study Patient**:
The single patient selected before a user-study run and kept fixed for that run. The Study Patient is not changed or synchronized by participants.

**Shared Handover State**:
The participant-visible handover choices and presentation state that must converge for everyone collaborating in the same session. It includes dashboard section arrangement, Spatial Card state, Orbit state, and Shared Abbreviation Selections; the Study Patient, local presentation effects, and connection status are excluded.
