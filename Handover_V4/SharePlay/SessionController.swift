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
    
    /// The coordinator owns this controller and applies received messages.
    private weak var coordinator: SharePlayCoordinator?
    private weak var replicator: SharedHandoverReplicator?
    
    /// Creates a session controller for the given group session.
    init?(
        _ groupSession: GroupSession<SharePlayTogether>,
        coordinator: SharePlayCoordinator,
        replicator: SharedHandoverReplicator
    ) async {
        guard let groupSystemCoordinator = await groupSession.systemCoordinator else {
            return nil
        }

        session = groupSession
        messenger = GroupSessionMessenger(session: session, deliveryMode: .reliable)
        systemCoordinator = groupSystemCoordinator
        self.coordinator = coordinator
        self.replicator = replicator

        observeCardMessages()
        observeReplicationMessages()
        observeOrbitMessages()
        observeDashboardMessages()
        observeCatchUpMessages()
        observeActiveRemoteParticipants()

        systemCoordinator.configuration.supportsGroupImmersiveSpace = true
        systemCoordinator.configuration.spatialTemplatePreference = .conversational
        session.join()
    }
    
    /// Ends the SharePlay session for all participants.
    func endSession() {
        session.end()
    }

    var localParticipantID: Participant.ID {
        session.localParticipant.id
    }
    // MARK: - Message observation

    private func observeCardMessages() {
        Task.immediate(name: "card message observation") {
            for await (message, _) in messenger.messages(of: CardSyncMessage.self) {
                guard let coordinator else { return }
                coordinator.handleRemoteCardMessage(message)
            }
        }
    }

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

    private func observeDashboardMessages() {
        Task.immediate(name: "dashboard message observation") {
            for await (message, _) in messenger.messages(of: DashboardSyncMessage.self) {
                guard let coordinator else { return }
                coordinator.handleRemoteDashboardMessage(message)
            }
        }
    }

    private func observeOrbitMessages() {
        Task.immediate(name: "orbit message observation") {
            for await (message, _) in messenger.messages(of: OrbitSyncMessage.self) {
                guard let coordinator else { return }
                coordinator.handleRemoteOrbitMessage(message)
            }
        }
    }
    
    private func observeCatchUpMessages() {
        Task.immediate(name: "catch-up message observation") {
            for await (message, _) in messenger.messages(of: CatchUpMessage.self) {
                guard let coordinator else { return }
                coordinator.applyCatchUpMessage(message)
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

                if !newActiveParticipants.isEmpty, let coordinator {
                    replicator?.sendCurrentState(
                        to: Set(newActiveParticipants.map(\.id))
                    )
                    coordinator.sendCatchUp(
                        to: Set(newActiveParticipants.map(\.id))
                    )
                }
            }
        }
    }

    // MARK: - Message transport

    func sendMessage(_ message: CardSyncMessage) {
        send(message, kind: "card")
    }

    func sendMessage(_ message: DashboardSyncMessage) {
        send(message, kind: "dashboard")
    }


    func sendMessage(_ message: OrbitSyncMessage) {
        send(message, kind: "orbit")
    }

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

    func sendMessage(
        _ message: CatchUpMessage,
        to participantIDs: Set<Participant.ID>
    ) {
        let participants = session.activeParticipants.filter {
            participantIDs.contains($0.id)
        }
        guard !participants.isEmpty else { return }
        send(message, to: .only(participants), kind: "catch-up")
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
