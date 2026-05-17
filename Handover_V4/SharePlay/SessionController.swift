//
//  SessionController.swift
//  Handover_V4
//
//  Created by Juvern Khor on 22/3/2026.
//

import Foundation
@preconcurrency import GroupActivities
import Observation
import Combine



/// Controls the SharePlay session for real-time card state synchronization.
@Observable
@MainActor
final class SessionController {
    let session: GroupSession<SharePlayTogether> /// The active SharePlay group session for the `SharePlayTogether`.
    private let messenger: GroupSessionMessenger /// synchronizing actions across participants
    private let systemCoordinator: SystemCoordinator ////// Coordinates spatial aspects of the SharePlay session for immersive spaces.
    
    /// The session controller updates the app model's color when receiving remote changes,
    /// but the app model owns the session controller life cycle.
    private weak var appModel: AppModel?
    
    /// Creates a session controller for the given group session.
    init?(_ groupSession: GroupSession<SharePlayTogether>, appModel: AppModel) async {
        // We MUST get the system coordinator for immersive spaces
        guard let groupSystemCoordinator = await groupSession.systemCoordinator else {
            return nil
        }
        // Keep track of the current session.
        session = groupSession
        // .reliable means "make sure this message arrives, even if it takes a split second longer"
        messenger = GroupSessionMessenger(session: session, deliveryMode: .reliable)

        systemCoordinator = groupSystemCoordinator
        self.appModel = appModel
        
        // Start observation tasks
        observeSyncMessages() // Listen for CardSyncMessage updates
        observeDashboardMessages() // Listen for DashboardSyncMessage updates
        observeCatchUpMessages() // Listen for CatchUpMessage
        observeActiveRemoteParticipants() //Monitors participant changes and sends the current state when new participants join
        
        // Configure the Immersive Space & Spatial Personas
            // Ensure support for the group immersive space
        
        systemCoordinator.configuration.supportsGroupImmersiveSpace = true
        systemCoordinator.configuration.spatialTemplatePreference = .sideBySide // Arrange the spatial persona in a converstation style

        // Connect to the room!
        session.join()
        
    }
    
    /// Ends the SharePlay session for all participants.
    func endSession() {
        session.end()
    }
    
    
    // MARK: - Observation Tasks
    // Observes incoming sync messages for individual card changes
    private func observeSyncMessages() {
        Task.immediate(name: "sync message observation") {
            for await (message, _) in messenger.messages(of: CardSyncMessage.self) {
                guard let appModel else { return }
                appModel.handleRemoteSyncMessage(message)
            }
        }
    }

    private func observeDashboardMessages() {
        Task.immediate(name: "dashboard message observation") {
            for await (message, _) in messenger.messages(of: DashboardSyncMessage.self) {
                guard let appModel else { return }
                appModel.handleRemoteDashboardSyncMessage(message)
            }
        }
    }
    
    /// Observes incoming catch-up message from other participants
    private func observeCatchUpMessages() {
        Task.immediate(name: "catch-up message observation") {
            for await (message, _) in messenger.messages(of: CatchUpMessage.self) {
                guard let appModel else { return }
                appModel.replaceAllSharedState(
                    states: message.allCardStates,
                    positions: message.allCardPositions,
                    cardUpdateCounts: message.cardUpdateCounts,
                    dashboardState: message.dashboardState,
                    dashboardUpdateCount: message.dashboardUpdateCount
                )
            }
        }
    }
    
    /// Observes when new participants join and sends them the current state
    private func observeActiveRemoteParticipants() {
        Task.immediate(name: "active participant observation") {
            var previousActiveParticipants = Set<Participant>()
            var hasSeenInitialParticipants = false
            
            // Iterate through active participants and remove inactive participants.
            for await activeParticipants in session.$activeParticipants.values {
                // 1. Filter out the local participant (we only care about remote joiners)
                let currentActiveParticipants = activeParticipants.filter { $0.id != session.localParticipant.id }
                
                // 2. Ensure previousActiveParticipants updates at the end of the loop, no matter what
                defer {
                    previousActiveParticipants = currentActiveParticipants
                    hasSeenInitialParticipants = true
                }

                guard hasSeenInitialParticipants else { continue }
                
                // 3. Find participants who just joined
                let newActiveParticipants = currentActiveParticipants.subtracting(previousActiveParticipants)
                
                if !newActiveParticipants.isEmpty, let appModel {
                    do {
                        let catchUpMessage = appModel.makeCatchUpMessage()
                        try await messenger.send(catchUpMessage, to: .only(newActiveParticipants))
                    } catch {
                        print("❌ Failed to send catch-up message: \(error)")
                    }
                }
            }
        }
    }
    
    // MARK: - Send MESSAGE
    func sendMessage(_ message: CardSyncMessage) async {
        do {
            try await messenger.send(message)
        } catch {
            print("❌ Failed to send sync message: \(error)")
        }
    }

    func sendMessage(_ message: DashboardSyncMessage) async {
        do {
            try await messenger.send(message)
        } catch {
            print("❌ Failed to send dashboard sync message: \(error)")
        }
    }
    
}
