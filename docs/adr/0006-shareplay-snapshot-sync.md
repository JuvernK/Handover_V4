---
status: accepted
---

# SharePlay shares one versioned snapshot

SharePlay sends everything participants see in common as one small
`SharedHandoverSnapshot`. Each change sends the whole snapshot with a
`SharedHandoverVersion` (change count, session join time, participant ID), and
every device keeps the newest one. The same message brings late joiners up to
date, so there is one rule for live updates, catch-up and conflicts. This follows
Apple's visionOS SharePlay sample: one reliable `GroupSessionMessenger`, an
update counter with a participant tiebreak, setup before `join()`, and a snapshot
sent to each arriving participant.

`AppModel` notices changes to the snapshot through observation and sends them, so
views need no SharePlay code. `SharedHandoverReplica` holds the send-and-apply
rules apart from GroupActivities and is checked by standalone tests.
`SessionController` only carries messages.

The user chose this on 26 October 2026 for a study with a few Vision Pro wearers
in one room, where everyone sees and can control the same handover. Shared:
immersion, mode, Orbit target, Spatial and Dashboard disclosure, SBAR focus and
section order. Local: head pose, window placement, dashboard scrolling and Orbit
drags before release.

## Considered options

- **Per-fact versions (the former `SharedHandoverReplicator`).** Concurrent
  edits to different facts survive, at the cost of more replication code and
  tests. The replicator was removed in PR #36, which returned to per-action
  messages.
- **Per-action messages (the previous `CardSyncMessage` design).** Rejected
  because each action needs its own message, ordering and catch-up handling, and
  none of the presentation modes were covered.
- **Streaming Orbit drags with unreliable delivery.** Rejected in favor of
  sharing the chosen card, which keeps one reliable channel.
- **A presenter role.** Rejected because anyone may control the handover.

## Consequences

- Two changes at the same moment keep only the later snapshot, even if they
  touched different facts. All devices still match.
- At equal change counts the earlier joiner wins, which depends on device clocks
  agreeing to within the seconds between joins.
- A new shared fact is one snapshot field plus its line in
  `AppModel.currentSnapshot` and `AppModel.receive(_:)`.
