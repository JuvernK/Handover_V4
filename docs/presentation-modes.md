# Presentation modes

Dashboard, Spatial, and Orbit are three ways to present the same patient
handover in the headset study. [CONTEXT.md](../CONTEXT.md) defines the study
terms. [SharePlay](shareplay.md) covers synchronization and two-device validation.

## Modes and controls

The three mutually exclusive modes support a headset user study:

- **Spatial**: cards at fixed patient and room points of interest. Tap a
  clinical card to expand or collapse it.
- **Orbit**: nine clinical cards, including Situation, arranged in a rotating
  carousel, with Basic Information permanently visible separately. Use the
  ring, Previous/Next buttons, or slider to navigate.
- **Dashboard**: the dashboard window inside immersion. Hide spatial cards and
  the orbit ring, keeping the ICU room visible. No standalone dashboard outside
  immersion.

Default to Dashboard on entering immersion outside an existing shared session. A participant-visible
` Dashboard | Spatial | Orbit ` segmented control lives in the persistent
launcher/control window. Any participant can switch modes.

Show only the active mode's controls in that window: SBAR in Spatial, carousel
controls in Orbit, and no extra card controls in Dashboard (which has its own
SBAR rail). Hide inactive controls. Mode switch, Exit, and SharePlay remain visible.
The SharePlay button reads Start SharePlay, or Leave SharePlay during a session.

## State and SharePlay

Entering Spatial or Dashboard resets all clinical sections to expanded,
including returning to a mode within the same session. Orbit is the exception:
each entry starts on Situation with all nine clinical cards collapsed, then
expands only Situation after the carousel settles. Basic Information remains
permanently visible separately. Do not persist disclosure across app restarts.

`AppModel` owns mode and disclosure state. A mode change carries its reset to
SharePlay peers. Each device opens or dismisses its own dashboard window through
`LauncherView`. The `Handover_V4/Presentation/` folders group mode-specific
code alongside shared clinical cards, scene integration, and launcher controls.

## Source outlines

- **Spatial** outlines the equipment associated with each expanded clinical card.
- **Orbit** outlines equipment only when the front card is expanded and the
  carousel has settled. Rotation or collapse clears the outline.
- **Dashboard** shows no equipment outlines. Cards without an equipment source
  produce no outline in any mode.

The equipment names in [`OrbitCard.equipmentNames`](../Handover_V4/Presentation/Orbit/OrbitPresentationState.swift)
match the authored ICU entities. Check that mapping when changing the scene.

## Reality Composer Pro authoring

Preserve the authored `OrbitAnchor` and slot transforms when changing carousel
behavior. The anchor sits outside the scaled ICU model. `OrbitGeometry` reads
its child markers in world space, sorts the nonnegative `OrbitSlotComponent`
indices to build the ring and carousel path, and uses index `-1` for Basic
Information. The current scene has eight path markers for the nine-card
carousel. Adjust the authored marker positions to resize or reshape the path.

## visionOS checks

Use the [visionOS Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/designing-for-visionos)
when designing windows, ornaments, and immersive interactions. Verify changes
to spatial UI in the running app and capture a screenshot when the result is
visual. Note any checks that still need a headset.

- Switch between modes and check the windows and disclosure resets. Immersion
  leaves existing windows open until the app explicitly dismisses them.
- In Orbit, test ring drag and release, front-card disclosure, and outlines
  clearing during motion and returning after settling. Check Spatial outlines
  against the expanded cards.
- Check taps after card sizes change. `ImmersiveSceneController` builds
  collision shapes once attachment bounds are finite and nonzero, then updates
  them when the measured bounds change.
- Check glass spacing and hover in the running app. Roughly 12–16 pt between
  glass surfaces helps keep them distinct. Apply hover to the outermost
  tappable container to avoid overlapping hover regions.
