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
final class SessionController {
    /// The active SharePlay group session.
    let session: GroupSession<SharePlayTogether>

    /// Transports reliable synchronization messages between participants.
    private let messenger: GroupSessionMessenger

    /// Configures spatial behavior for the group immersive space.
    private let systemCoordinator: SystemCoordinator
    
    /// The coordinator owns this controller and applies received messages.
    private weak var coordinator: SharePlayCoordinator?
    
    /// Creates a session controller for the given group session.
    init?(
        _ groupSession: GroupSession<SharePlayTogether>,
        coordinator: SharePlayCoordinator
    ) async {
        guard let groupSystemCoordinator = await groupSession.systemCoordinator else {
            return nil
        }

        session = groupSession
        messenger = GroupSessionMessenger(session: session, deliveryMode: .reliable)
        systemCoordinator = groupSystemCoordinator
        self.coordinator = coordinator

        observeCardMessages()
        observeDashboardMessages()
        observeCatchUpMessages()
        observeActiveRemoteParticipants()

        systemCoordinator.configuration.supportsGroupImmersiveSpace = true
        systemCoordinator.configuration.spatialTemplatePreference = .none
        session.join()
    }
    
    /// Ends the SharePlay session for all participants.
    func endSession() {
        session.end()
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

    private func observeDashboardMessages() {
        Task.immediate(name: "dashboard message observation") {
            for await (message, _) in messenger.messages(of: DashboardSyncMessage.self) {
                guard let coordinator else { return }
                coordinator.handleRemoteDashboardMessage(message)
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
                    do {
                        let catchUpMessage = coordinator.makeCatchUpMessage()
                        try await messenger.send(
                            catchUpMessage,
                            to: .only(newActiveParticipants)
                        )
                    } catch {
                        print("Failed to send catch-up message: \(error)")
                    }
                }
            }
        }
    }

    // MARK: - Message transport

    func sendMessage(_ message: CardSyncMessage) async {
        do {
            try await messenger.send(message)
        } catch {
            print("Failed to send card sync message: \(error)")
        }
    }

    func sendMessage(_ message: DashboardSyncMessage) async {
        do {
            try await messenger.send(message)
        } catch {
            print("Failed to send dashboard sync message: \(error)")
        }
    }
}
