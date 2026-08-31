---
status: accepted
---

# Spatial Card Handle owns card manipulation

Spatial Card manipulation is restricted to the full-width **Card Handle** in the card's top bar: a tap expands or collapses the card, while a pinch-and-move beyond the drag threshold cancels the tap and moves the card. Clinical content never initiates card movement. This supersedes the whole-card-drag gesture ownership retained by ADR 0002 because whole-card dragging competes with small inline abbreviation controls and can carry a card out of reach; the full-width handle preserves a large visionOS target without giving every interactive field two meanings.

In Orbit, Card Handle dragging is disabled and Spatial Cards cannot be moved individually. Orbit navigation uses the draggable Orbit ring, floating Previous and Next controls beside the Focused Card, and a snapping slider in the immersive-controls window. Dragging a Spatial Card does not navigate the Orbit.
