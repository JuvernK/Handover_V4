//
//  SharePlayMessageTransport.swift
//  Handover_V4
//

import Foundation
import GroupActivities

/// The message boundary used by SharePlayCoordinator.
///
/// Keeping GroupSessionMessenger behind this interface lets synchronization
/// behavior be exercised with an in-memory two-participant transport.
@MainActor
protocol SharePlayMessageTransport: ReplicationTransport {
    var localParticipantID: Participant.ID { get }

    func endSession()
    func sendMessage(_ message: DashboardSyncMessage)
    func sendMessage(_ message: OrbitSyncMessage)
    func sendMessage(
        _ message: CatchUpMessage,
        to participantIDs: Set<Participant.ID>
    )
}
