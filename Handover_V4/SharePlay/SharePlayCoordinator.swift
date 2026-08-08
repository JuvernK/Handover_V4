//
//  SharePlayCoordinator.swift
//  Handover_V4
//

import Foundation
import Observation
@preconcurrency import GroupActivities
import Combine

/// Coordinates SharePlay activation and active-session lifecycle.
@Observable
@MainActor
final class SharePlayCoordinator {
    private let replicator: SharedHandoverReplicator

    private var sessionController: SessionController?
    private var isObservingSessions = false

    private(set) var isActivating = false
    var errorMessage: String?

    var isActive: Bool {
        sessionController != nil
    }

    init(
        replicator: SharedHandoverReplicator
    ) {
        self.replicator = replicator
    }

    // MARK: - Session lifecycle

    func startObservingSessions() {
        guard !isObservingSessions else { return }
        isObservingSessions = true

        Task(name: "group session observation") {
            await observeGroupSessions()
        }
    }

    func activate() async {
        guard !isActive, !isActivating else { return }

        isActivating = true
        errorMessage = nil
        defer { isActivating = false }

        let activity = SharePlayTogether()
        switch await activity.prepareForActivation() {
        case .activationPreferred:
            do {
                _ = try await activity.activate()
            } catch {
                errorMessage = "SharePlay could not be started: \(error.localizedDescription)"
            }
        case .activationDisabled:
            errorMessage = "Start or join a FaceTime call before starting SharePlay."
        case .cancelled:
            break
        @unknown default:
            errorMessage = "SharePlay is not available right now."
        }
    }

    func endSession() {
        sessionController?.endSession()
    }

    private func observeGroupSessions() async {
        for await session in SharePlayTogether.sessions() {
            guard let controller = await SessionController(
                session,
                replicator: replicator
            ) else {
                continue
            }

            sessionController = controller
            replicator.attach(controller)
            observeInvalidation(of: session)
        }
    }

    private func observeInvalidation(
        of session: GroupSession<SharePlayTogether>
    ) {
        Task.immediate(name: "session state observation") {
            for await state in session.$state.values {
                guard sessionController?.session.id == session.id else {
                    return
                }
                if case .invalidated = state {
                    sessionController = nil
                    replicator.detach()
                    return
                }
            }
        }
    }

}
