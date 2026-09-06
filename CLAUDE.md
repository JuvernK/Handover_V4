# Handover V4 — Project Instructions

## visionOS development guidelines

Apple's official references for spatial UI work on this project:

- **Human Interface Guidelines — Designing for visionOS**
  https://developer.apple.com/design/human-interface-guidelines/designing-for-visionos
  Read this before designing any new window, ornament, or immersive interaction.
- **visionOS developer documentation (SwiftUI, RealityKit, ARKit for visionOS)**
  https://developer.apple.com/documentation/visionos
- **RealityKit framework reference**
  https://developer.apple.com/documentation/realitykit
- **SwiftUI framework reference**
  https://developer.apple.com/documentation/swiftui

When a design decision or bug looks visionOS-specific, check the HIG page above before guessing — spatial interaction rules (hover, gaze, ornaments, immersion styles) often behave differently from iOS/macOS assumptions.

### Gotchas found in this codebase (verified on-device/simulator, not just guessed)


- **Adjacent glass panels can visually merge.** `glassBackgroundEffect` surfaces placed with very little spacing may blend into one shape. Keep at least ~12-16pt gap between separate cards.
- **Windows do not auto-dismiss when entering an immersive space.** A `WindowGroup` stays open unless your code explicitly calls `dismissWindow`. Don't assume the dashboard disappears — check `Handover_V4App.swift` / `ToggleImmersiveSpaceButton.swift` for the actual behavior.
- **RealityKit attachments need real, non-zero SwiftUI-measured size before they're interactive.** `ImmersiveView.swift` polls `visualBounds` for up to 2 seconds before building the collision shape used for tap/drag. Skipping this makes gestures silently not work.
- **`.hoverEffect()` should sit on the outermost tappable container**, not on a child view inside another tappable parent — nesting it can create two overlapping hover regions.
- **Always verify in the simulator or on-device, not just SwiftUI previews.** Previews do not reproduce hover-lift, focus, or immersive-space behavior. The `Button` overlap bug above was invisible in preview and only showed when actually running the app — screenshot the running app before calling spatial UI work done.

## Other project conventions

See `AGENTS.md` in this repo for product direction, branch strategy, and documentation conventions.
