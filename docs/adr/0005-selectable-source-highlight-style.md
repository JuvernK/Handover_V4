---
status: accepted
---

# Selectable Source Highlight Style

Equipment Source Highlights have a participant-local **Source Highlight Style**: `outline` is the default and renders the normally visible outer silhouette in the card's Card Identity Colour, while `glow` retains the emissive treatment chosen in ADR 0001. An explicit Outline/Glow segmented control appears in the immersive-controls window; the preference survives immersive-space re-entry during one app session, returns to Outline on a new launch, and is not synchronized through SharePlay. Organ Sources retain their tinted placards.

The outline does not colour equipment surfaces, reveal internal mesh edges, or render through occluding geometry. Switching styles briefly cross-fades the presentation and respects Reduce Motion. This supersedes only ADR 0001's emissive-only visual treatment; its Source mapping, active-card derivation, local controller, and no-extra-SharePlay-message decisions remain accepted.
