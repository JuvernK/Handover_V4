//
//  SessionController.swift
//  Handover_V4
//
//  Created by Juvern Khor on 22/3/2026.
//

import Foundation
@preconcurrency import GroupActivities
import Combine

/// Controls the SharePlay session for real-time card state synchronization.
@MainActor
final class SessionController: SharePlayMessageTransport {
    /// The active SharePlay group session.
    let session: GroupSession<SharePlayTogether>

    /// Transports reliable synchronization messages between participants.
    private let messenger: GroupSessionMessenger

    /// Configures spatial behavior for the group immersive space.
    private let systemCoordinator: SystemCoordinator
    
    private weak var replicator: SharedHandoverReplicator?
    
    /// Creates a session controller for the given group session.
    init?(
        _ groupSession: GroupSession<SharePlayTogether>,
        replicator: SharedHandoverReplicator
    ) async {
        guard let groupSystemCoordinator = await groupSession.systemCoordinator else {
            return nil
        }

        session = groupSession
        messenger = GroupSessionMessenger(session: session, deliveryMode: .reliable)
        systemCoordinator = groupSystemCoordinator
        self.replicator = replicator

        observeReplicationMessages()
        observeActiveRemoteParticipants()

        systemCoordinator.configuration.supportsGroupImmersiveSpace = true
        systemCoordinator.configuration.spatialTemplatePreference = .conversational
        session.join()
    }
    
    /// Ends the SharePlay session for all participants.
    func endSession() {
        session.end()
    }

    // MARK: - Message observation

    private func observeReplicationMessages() {
        Task.immediate(name: "replication envelope observation") {
            for await (message, _) in messenger.messages(
                of: ReplicationEnvelope.self
            ) {
                guard let replicator else { return }
                replicator.receive(message)
            }
        }
    }

    private func observeActiveRemoteParticipants() {
        Task.immediate(name: "active participant observation") {
            var previousActiveParticipants = Set<Participant>()
            var hasSeenInitialParticipants = false
            
            for await activeParticipants in session.$activeParticipants.values {
                let currentActiveParticipants = activeParticipants.filter {
                    $0.id != session.localParticipant.id
                }

                defer {
                    previousActiveParticipants = currentActiveParticipants
                    hasSeenInitialParticipants = true
                }

                guard hasSeenInitialParticipants else { continue }

                let newActiveParticipants = currentActiveParticipants
                    .subtracting(previousActiveParticipants)

                if !newActiveParticipants.isEmpty {
                    replicator?.sendCurrentState(
                        to: Set(newActiveParticipants.map(\.id))
                    )
                }
            }
        }
    }

    // MARK: - Message transport

    func send(_ envelope: ReplicationEnvelope) {
        send(envelope, kind: "replication")
    }

    func send(
        _ envelope: ReplicationEnvelope,
        to participantIDs: Set<UUID>
    ) {
        let participants = session.activeParticipants.filter {
            participantIDs.contains($0.id)
        }
        guard !participants.isEmpty else { return }
        send(envelope, to: .only(participants), kind: "replication")
    }

    private func send<Message: Codable>(
        _ message: Message,
        to participants: Participants = .all,
        kind: String
    ) {
        Task {
            do {
                try await messenger.send(message, to: participants)
            } catch {
                print("Failed to send \(kind) sync message: \(error)")
            }
        }
    }
}
