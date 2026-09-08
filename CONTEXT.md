# Handover

Language for presenting a patient handover within the immersive ICU experience.

## Language

**Presentation mode**:
One of three mutually exclusive ways to present a handover: Spatial, Orbit, or Dashboard.

**Spatial mode**:
The presentation mode in which clinical cards occupy fixed points of interest in the immersive environment and cannot be freely dragged.
_Avoid_: Situated mode (a synonym; use Spatial consistently).

**Orbit mode**:
The presentation mode in which nine clinical cards, including Situation, are arranged in a rotating carousel. Basic Information is the permanent patient introduction, shown separately from the carousel.

**Orbit Navigation**:
The controls that bring a clinical card to the carousel's front reading position: a draggable ring, Previous/Next buttons, and a nine-position slider. Navigation settles on a card and automatically expands it.

**Dashboard mode**:
The presentation mode in which the handover appears in a dashboard window and spatial cards are hidden.

**Point of interest**:
An authored location on the patient or in the room associated with clinical information.

**Source**:
The real-world origin associated with a clinical card's data, such as a piece of equipment in the ICU. A card may have no physical source.

**Active Card**:
A clinical card eligible to highlight its Source: the expanded front card after Orbit settles, or any expanded clinical card in Spatial mode. No card activates a Source Highlight during Orbit rotation or in Dashboard mode.

**Source Highlight**:
The outline applied to an Active Card's equipment Source to identify its relationship to that card.
