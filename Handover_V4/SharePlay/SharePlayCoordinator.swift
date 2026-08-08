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
    private var orbitUpdateCount: MessageUpdateCount?
    private var lastOrbitBroadcastTime = Date.distantPast
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
                coordinator: self,
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

    // MARK: - Local orbit updates

    func applyOrbitTransition(_ transition: OrbitTransition) {
        let previousSelections = sharedCardState.abbreviationSelections
        sharedCardState.setOrbitState(
            transition.state,
            animationDuration: transition.animationDuration
        )
        recordClearedAbbreviations(from: previousSelections)

        let now = Date()
        guard transition.isFinal
                || now.timeIntervalSince(lastOrbitBroadcastTime) >= 0.05 else {
            return
        }
        lastOrbitBroadcastTime = now
        broadcastOrbitState(
            transition.state,
            isFinal: transition.isFinal
        )
    }

    private func broadcastOrbitState(_ state: OrbitState, isFinal: Bool) {
        guard let updateCount = nextUpdateCount(after: orbitUpdateCount) else {
            return
        }

        orbitUpdateCount = updateCount
        let message = OrbitSyncMessage(
            state: state,
            updateCount: updateCount,
            isFinal: isFinal
        )
        transport?.sendMessage(message)
    }

    private func nextUpdateCount(
        after existingCount: MessageUpdateCount?
    ) -> MessageUpdateCount? {
        guard let participantID = transport?.localParticipantID else {
            return nil
        }

        return MessageUpdateCount(
            count: (existingCount?.count ?? 0) + 1,
            participant: participantID
        )
    }

    func attachTransport(_ transport: any SharePlayMessageTransport) {
        self.transport = transport
        replicator.attach(transport)
    }

    func detachTransport() {
        transport = nil
        replicator.detach()
    }

    private func recordClearedAbbreviations(
        from previousSelections: [ClinicalCardID: AbbreviationSelection]
    ) {
        let clearedCardIDs = Set(previousSelections.keys).subtracting(
            sharedCardState.abbreviationSelections.keys
        )
        replicator.transact(.clearAbbreviations(clearedCardIDs))
    }

    // MARK: - Remote updates

    func handleRemoteOrbitMessage(_ message: OrbitSyncMessage) {
        if let existingCount = orbitUpdateCount,
           message.updateCount <= existingCount {
            return
        }

        orbitUpdateCount = message.updateCount
        let previousSelections = sharedCardState.abbreviationSelections
        sharedCardState.setOrbitState(
            message.state,
            animationDuration: message.isFinal ? 0.22 : 0.08
        )
        recordClearedAbbreviations(from: previousSelections)
    }

    func applyCatchUpMessage(_ message: CatchUpMessage) {
        let orbitSnapshot = mergedOrbitSnapshot(with: message)
        let previousSelections = sharedCardState.abbreviationSelections
        sharedCardState.setOrbitState(
            orbitSnapshot.state,
            animationDuration: 0.35
        )
        recordClearedAbbreviations(from: previousSelections)
        orbitUpdateCount = orbitSnapshot.updateCount
    }

    func sendCatchUp(to participantIDs: Set<Participant.ID>) {
        guard !participantIDs.isEmpty else { return }
        transport?.sendMessage(
            makeCatchUpMessage(),
            to: participantIDs
        )
    }

    func makeCatchUpMessage() -> CatchUpMessage {
        CatchUpMessage(
            orbitState: sharedCardState.orbitState,
            orbitUpdateCount: orbitUpdateCount
        )
    }

    private func mergedOrbitSnapshot(
        with message: CatchUpMessage
    ) -> (state: OrbitState, updateCount: MessageUpdateCount?) {
        guard let incomingCount = message.orbitUpdateCount else {
            return orbitUpdateCount == nil
                ? (message.orbitState, nil)
                : (sharedCardState.orbitState, orbitUpdateCount)
        }
        if let currentCount = orbitUpdateCount,
           incomingCount <= currentCount {
            return (sharedCardState.orbitState, orbitUpdateCount)
        }
        return (message.orbitState, incomingCount)
    }
}
