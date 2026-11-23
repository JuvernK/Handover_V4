# Handover V4

Handover V4 is a visionOS research prototype for ICU handover. Explore within the study scope, reuse existing components where they fit, and record decisions that change the study setup or a shared architecture boundary.

When a change has a meaningful impact, summarize its main benefit and downside in one sentence.

Start implementation on a task branch from `main`. Get approval before merging or pushing. After an approved merge, verify the changes are in `main` and remove the local task branch once it is clean and unused.

Reproduce bugs through the affected user flow first. For Swift changes, run `sh Tests/run-checks.sh` and build the visionOS app:

```sh
xcodebuild -project Handover_V4.xcodeproj -scheme Handover_V4 -destination 'generic/platform=visionOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

- **Presentation and scene**: see [presentation modes](docs/presentation-modes.md) for interactions, RealityKit authoring, and simulator or device checks.
- **Synchronization**: see [SharePlay](docs/shareplay.md) for shared state and two-device validation.
- **Terminology and decisions**: see [CONTEXT.md](CONTEXT.md) and the relevant [ADRs](docs/adr/).
