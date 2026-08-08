//
//  SharePlayCoordinator.swift
//  Handover_V4
//

import Foundation
import Observation
@preconcurrency import GroupActivities
import Combine

/// Coordinates SharePlay lifecycle and synchronizes app feature state.
@Observable
@MainActor
final class SharePlayCoordinator {
    private let sharedCardState: SharedCardState
    private let replicator: SharedHandoverReplicator

    private var sessionController: SessionController?
    private var transport: (any SharePlayMessageTransport)?
    private var isObservingSessions = false

    private(set) var isActivating = false
    var errorMessage: String?

    var isActive: Bool {
        transport != nil
    }

    init(
        sharedCardState: SharedCardState,
        replicator: SharedHandoverReplicator,
        transport: (any SharePlayMessageTransport)? = nil
    ) {
        self.sharedCardState = sharedCardState
        self.replicator = replicator
        self.transport = transport
        if let transport {
            replicator.attach(transport)
        }
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
        transport?.endSession()
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
            attachTransport(controller)
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
                    detachTransport()
                    return
                }
            }
        }
    }

    // MARK: - Local card updates

    func setCardState(
        _ cardID: ClinicalCardID,
        isExpanded: Bool,
        syncChanges: Bool
    ) {
        if syncChanges {
            replicator.transact(
                .setCardExpansion(cardID, isExpanded: isExpanded)
            )
        } else {
            sharedCardState.setExpansionState(isExpanded, for: cardID)
        }
    }

    func setCardPosition(
        _ cardID: ClinicalCardID,
        position: SIMD3<Float>,
        syncChanges: Bool
    ) {
        if syncChanges {
            replicator.transact(.moveCard(cardID, to: position))
        } else {
            sharedCardState.setPosition(position, for: cardID)
        }
    }

    // MARK: - Local abbreviation updates

    func toggleAbbreviationSelection(
        _ selection: AbbreviationSelection,
        for cardID: ClinicalCardID
    ) {
        replicator.transact(.toggleAbbreviation(selection, in: cardID))
    }

    func attachTransport(_ transport: any SharePlayMessageTransport) {
        self.transport = transport
        replicator.attach(transport)
    }

    func detachTransport() {
        transport = nil
        replicator.detach()
    }

}
