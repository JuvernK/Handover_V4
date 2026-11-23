// Flow: AppModel -> SharedHandoverSnapshot + SharedHandoverVersion -> SessionController -> GroupSessionMessenger.
import Foundation

/// Everything SharePlay participants see in common, sent whole on every change.
///
/// One small value keeps live updates, late joining and conflicts to a single rule:
/// the snapshot with the newest `SharedHandoverVersion` wins on every device.
/// Head pose, window placement, dashboard scrolling and an Orbit drag that has not
/// been released stay local, because they belong to one person's view.
struct SharedHandoverSnapshot: Codable, Equatable, Sendable {
    /// Whether the ICU immersive space is open.
    var isImmersed = false
    var mode = PresentationMode.dashboard
    /// The card Orbit is heading for; nil outside Orbit.
    var orbit: OrbitTarget?
    /// Spatial cards default to expanded, so only exceptions are stored.
    var collapsedSpatialCards: Set<String> = []
    var dashboard = DashboardPresentationState()
    var dashboardOrder = DashboardBoardState()
}

/// Orders snapshots the same way on every device, so peers converge without a host.
struct SharedHandoverVersion: Codable, Comparable, Sendable {
    /// Changes made during this SharePlay session; 0 means the sender has made none yet.
    var count: Int
    /// When the author joined the session. At equal counts the earlier joiner wins, so
    /// someone joining late adopts the group's state instead of imposing their own.
    var joinedAt: Date
    var participant: UUID

    /// The first change after `self`, made by the local participant.
    func next(joinedAt: Date, participant: UUID) -> Self {
        Self(count: count + 1, joinedAt: joinedAt, participant: participant)
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.count != rhs.count { return lhs.count < rhs.count }
        if lhs.joinedAt != rhs.joinedAt { return lhs.joinedAt > rhs.joinedAt }
        return lhs.participant.uuidString < rhs.participant.uuidString
    }
}

/// The only SharePlay message: a full snapshot, used for live changes and late-join catch-up alike.
struct SharedHandoverMessage: Codable, Sendable {
    let snapshot: SharedHandoverSnapshot
    let version: SharedHandoverVersion
}
