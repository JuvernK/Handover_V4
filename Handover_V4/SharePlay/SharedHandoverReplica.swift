// Flow: AppModel -> SharedHandoverReplica -> SharedHandoverMessage -> SessionController; remote messages return the same way.
import Foundation

/// This device's copy of the shared snapshot and its version, kept apart from SharePlay
/// plumbing so the convergence rules can be checked without a session.
///
/// AppModel reports every local snapshot; the replica decides whether it is a change
/// worth sending, and whether a received snapshot is newer than what this device shows.
/// A snapshot applied from a peer becomes the shared value, so re-reading it locally
/// never echoes it back.
struct SharedHandoverReplica {
    /// The last snapshot sent or adopted during the session.
    private(set) var shared = SharedHandoverSnapshot()
    private(set) var version: SharedHandoverVersion?
    private var participant: UUID?
    private var joinedAt = Date.distantPast

    var isActive: Bool { participant != nil }

    /// Starts a session from this device's current view, with no changes counted yet.
    mutating func begin(participant: UUID, joinedAt: Date, snapshot: SharedHandoverSnapshot) {
        self.participant = participant
        self.joinedAt = joinedAt
        shared = snapshot
        version = SharedHandoverVersion(count: 0, joinedAt: joinedAt, participant: participant)
    }

    mutating func end() {
        participant = nil
        version = nil
    }

    /// Returns a message to send when a local change alters what peers should see.
    mutating func localChange(_ snapshot: SharedHandoverSnapshot) -> SharedHandoverMessage? {
        guard let participant, let version, snapshot != shared else { return nil }
        let next = version.next(joinedAt: joinedAt, participant: participant)
        shared = snapshot
        self.version = next
        return SharedHandoverMessage(snapshot: snapshot, version: next)
    }

    /// Returns the snapshot to apply when a peer's message is newer than this device's.
    mutating func receive(_ message: SharedHandoverMessage) -> SharedHandoverSnapshot? {
        guard isActive, let version, message.version > version else { return nil }
        self.version = message.version
        shared = message.snapshot
        return message.snapshot
    }

    /// The full current state for a participant who just arrived.
    var catchUp: SharedHandoverMessage? {
        version.map { SharedHandoverMessage(snapshot: shared, version: $0) }
    }
}
