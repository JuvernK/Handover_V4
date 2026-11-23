// Flow: AppModel.observeGroupSessions -> SessionController -> GroupSessionMessenger <-> AppModel.receive(_:).
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

/// Owns one SharePlay session's lifecycle and transport. It carries `SharedHandoverMessage`
/// snapshots without interpreting them; AppModel and `SharedHandoverReplica` decide what they mean.
@Observable
@MainActor
final class SessionController {
    let session: GroupSession<SharePlayTogether>
    /// Reliable delivery: every message is settled state, and a lost one would leave a peer behind.
    private let messenger: GroupSessionMessenger
    private let systemCoordinator: SystemCoordinator

    /// AppModel owns this controller's lifetime, so the back reference is weak.
    private weak var appModel: AppModel?

    /// Prepares the session, then joins it. Returns nil when the session has no system coordinator,
    /// which a shared immersive space requires.
    init?(_ groupSession: GroupSession<SharePlayTogether>, appModel: AppModel) async {
        guard let groupSystemCoordinator = await groupSession.systemCoordinator else {
            return nil
        }
        session = groupSession
        messenger = GroupSessionMessenger(session: session, deliveryMode: .reliable)
        systemCoordinator = groupSystemCoordinator
        self.appModel = appModel

        // Listen before joining so no message or arriving participant is missed.
        observeMessages()
        observeArrivingParticipants()

        // One shared ICU for everyone, so people in the same room see the bed in the same place.
        systemCoordinator.configuration.supportsGroupImmersiveSpace = true
        systemCoordinator.configuration.spatialTemplatePreference = .sideBySide

        session.join()
    }

    /// Leaves the session for this device only; everyone else keeps sharing.
    func leave() {
        session.leave()
    }

    /// Sends a snapshot to every other participant.
    func send(_ message: SharedHandoverMessage) {
        Task {
            do {
                try await messenger.send(message)
            } catch {
                print("❌ Failed to send SharePlay snapshot: \(error)")
            }
        }
    }

    private func observeMessages() {
        Task.immediate(name: "SharePlay snapshot observation") {
            for await (message, _) in messenger.messages(of: SharedHandoverMessage.self) {
                appModel?.receive(message)
            }
        }
    }

    /// Sends the current snapshot to each participant as they arrive. Every participant does this,
    /// and the version ordering keeps whichever copy is newest, so no host is needed.
    private func observeArrivingParticipants() {
        Task.immediate(name: "SharePlay participant observation") {
            var previous = Set<Participant>()
            for await active in session.$activeParticipants.values {
                let remote = active.filter { $0.id != session.localParticipant.id }
                defer { previous = remote }
                let arrived = remote.subtracting(previous)
                guard !arrived.isEmpty, let message = appModel?.catchUpMessage else { continue }
                do {
                    try await messenger.send(message, to: .only(arrived))
                } catch {
                    print("❌ Failed to send SharePlay catch-up: \(error)")
                }
            }
        }
    }
}
