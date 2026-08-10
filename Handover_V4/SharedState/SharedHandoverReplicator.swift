import Foundation

enum SharedHandoverTransaction {
    case setCardExpansion(ClinicalCardID, isExpanded: Bool)
    case moveCard(ClinicalCardID, to: SIMD3<Float>)
    case moveDashboardSection(SectionID, toPositionOf: SectionID)
    case setOrbit(OrbitTransition)
    case toggleAbbreviation(
        AbbreviationSelection,
        in: ClinicalCardID
    )
}

enum ReplicationFactID: Codable, Hashable {
    case cardExpansion(ClinicalCardID)
    case cardPosition(ClinicalCardID)
    case abbreviationSelection(ClinicalCardID)
    case dashboardOrder
    case orbit
}

enum ReplicationFactValue: Codable, Equatable {
    case cardExpansion(Bool)
    case cardPosition(SIMD3<Float>)
    case abbreviationSelection(AbbreviationSelection?)
    case dashboardOrder([SectionID])
    case orbit(OrbitState, isFinal: Bool)
}

struct ReplicationVersion: Codable, Hashable, Comparable {
    let count: Int
    let participantID: UUID

    static func < (
        lhs: ReplicationVersion,
        rhs: ReplicationVersion
    ) -> Bool {
        if lhs.count != rhs.count {
            return lhs.count < rhs.count
        }
        return lhs.participantID.uuidString < rhs.participantID.uuidString
    }
}

struct VersionedReplicationFact: Codable, Equatable {
    let id: ReplicationFactID
    let value: ReplicationFactValue
    let version: ReplicationVersion
}

struct ReplicationEnvelope: Codable, Equatable {
    let facts: [VersionedReplicationFact]
}

@MainActor
protocol ReplicationTransport: AnyObject {
    func send(_ envelope: ReplicationEnvelope)
    func send(_ envelope: ReplicationEnvelope, to participantIDs: Set<UUID>)
}

/// Converges Shared Handover State facts through one state-oriented interface.
@MainActor
final class SharedHandoverReplicator {
    private let participantID: UUID
    private let sharedCardState: SharedCardState
    private let handoverViewModel: HandoverViewModel
    private var facts: [ReplicationFactID: VersionedReplicationFact] = [:]
    private var disconnectedChanges: Set<ReplicationFactID> = []
    private var pendingTransientFacts: [
        ReplicationFactID: VersionedReplicationFact
    ] = [:]
    private var scheduledTransientSend: (any OrbitScheduledAction)?
    private weak var transport: (any ReplicationTransport)?
    private let scheduler: any OrbitScheduling

    init(
        participantID: UUID = UUID(),
        sharedCardState: SharedCardState,
        handoverViewModel: HandoverViewModel,
        scheduler: (any OrbitScheduling)? = nil
    ) {
        self.participantID = participantID
        self.sharedCardState = sharedCardState
        self.handoverViewModel = handoverViewModel
        self.scheduler = scheduler ?? TaskOrbitScheduler()
    }

    @discardableResult
    func transact(_ transaction: SharedHandoverTransaction) -> Bool {
        let changedFacts: [VersionedReplicationFact]

        switch transaction {
        case .setCardExpansion(let cardID, let isExpanded):
            changedFacts = makeExpansionFacts(
                for: cardID,
                isExpanded: isExpanded
            )

        case .moveCard(let cardID, let position):
            changedFacts = [
                makeFact(
                    id: .cardPosition(cardID),
                    value: .cardPosition(position)
                )
            ]

        case .moveDashboardSection(let dragged, let destination):
            guard handoverViewModel.moveSection(
                dragged,
                toPositionOf: destination
            ) else {
                return false
            }
            changedFacts = [
                makeFact(
                    id: .dashboardOrder,
                    value: .dashboardOrder(handoverViewModel.sectionOrder)
                )
            ]

        case .setOrbit(let transition):
            changedFacts = makeOrbitFacts(for: transition)
            let envelope = ReplicationEnvelope(facts: changedFacts)
            merge(
                envelope,
                orbitAnimationDuration: transition.animationDuration
            )
            distributeOrbitFacts(
                changedFacts,
                isFinal: transition.isFinal
            )
            return true

        case .toggleAbbreviation(let selection, let cardID):
            guard sharedCardState.isCardExpanded(cardID) else {
                return false
            }
            let selectedValue = sharedCardState.abbreviationSelections[cardID]
                == selection ? nil : selection
            changedFacts = [
                makeFact(
                    id: .abbreviationSelection(cardID),
                    value: .abbreviationSelection(selectedValue)
                )
            ]

        }

        merge(ReplicationEnvelope(facts: changedFacts))
        distributeLocalFacts(changedFacts)
        return true
    }

    func receive(_ envelope: ReplicationEnvelope) {
        merge(envelope)
    }

    func attach(_ transport: any ReplicationTransport) {
        self.transport = transport
        guard !disconnectedChanges.isEmpty else { return }

        let latestFacts = disconnectedChanges.compactMap { facts[$0] }
        disconnectedChanges.removeAll()
        guard !latestFacts.isEmpty else { return }
        transport.send(ReplicationEnvelope(facts: latestFacts))
    }

    func detach() {
        scheduledTransientSend?.cancel()
        scheduledTransientSend = nil
        disconnectedChanges.formUnion(pendingTransientFacts.keys)
        pendingTransientFacts.removeAll()
        transport = nil
    }

    func sendCurrentState(to participantIDs: Set<UUID>) {
        guard !participantIDs.isEmpty, !facts.isEmpty else { return }
        transport?.send(
            ReplicationEnvelope(facts: Array(facts.values)),
            to: participantIDs
        )
    }

    private func makeExpansionFacts(
        for cardID: ClinicalCardID,
        isExpanded: Bool
    ) -> [VersionedReplicationFact] {
        var changes = [
            makeFact(
                id: .cardExpansion(cardID),
                value: .cardExpansion(isExpanded)
            )
        ]
        if !isExpanded {
            changes.append(
                makeFact(
                    id: .abbreviationSelection(cardID),
                    value: .abbreviationSelection(nil)
                )
            )
        }
        return changes
    }

    private func makeOrbitFacts(
        for transition: OrbitTransition
    ) -> [VersionedReplicationFact] {
        let state = transition.state
        let previousState = sharedCardState.orbitState
        let selections = sharedCardState.abbreviationSelections
        var clearedCardIDs: Set<ClinicalCardID> = []

        if state.isActive && !previousState.isActive {
            clearedCardIDs = Set(selections.keys)
        } else if let previouslyExpandedName = previousState.expandedCardName,
                  state.expandedCardName != previouslyExpandedName,
                  let cardID = ClinicalCardID(
                    canonicalName: previouslyExpandedName
                  ),
                  selections[cardID] != nil {
            clearedCardIDs.insert(cardID)
        }

        var changes = [
            makeFact(
                id: .orbit,
                value: .orbit(state, isFinal: transition.isFinal)
            )
        ]
        changes.append(contentsOf: clearedCardIDs.map { cardID in
            makeFact(
                id: .abbreviationSelection(cardID),
                value: .abbreviationSelection(nil)
            )
        })
        return changes
    }

    private func makeFact(
        id: ReplicationFactID,
        value: ReplicationFactValue
    ) -> VersionedReplicationFact {
        VersionedReplicationFact(
            id: id,
            value: value,
            version: ReplicationVersion(
                count: (facts[id]?.version.count ?? 0) + 1,
                participantID: participantID
            )
        )
    }

    private func distributeLocalFacts(
        _ changedFacts: [VersionedReplicationFact]
    ) {
        let envelope = ReplicationEnvelope(facts: changedFacts)
        if let transport {
            transport.send(envelope)
        } else {
            disconnectedChanges.formUnion(changedFacts.map(\.id))
        }
    }

    private func distributeOrbitFacts(
        _ changedFacts: [VersionedReplicationFact],
        isFinal: Bool
    ) {
        let facts = changedFacts
        guard transport != nil else {
            disconnectedChanges.formUnion(facts.map(\.id))
            return
        }

        pendingTransientFacts.merge(
            Dictionary(uniqueKeysWithValues: facts.map { ($0.id, $0) })
        ) { _, latest in latest }

        if isFinal {
            scheduledTransientSend?.cancel()
            scheduledTransientSend = nil
            sendPendingTransientFacts()
        } else if scheduledTransientSend == nil {
            scheduledTransientSend = scheduler.schedule(after: 0.05) {
                [weak self] in
                self?.sendPendingTransientFacts()
            }
        }
    }

    private func sendPendingTransientFacts() {
        scheduledTransientSend = nil
        guard !pendingTransientFacts.isEmpty else { return }
        let envelope = ReplicationEnvelope(
            facts: Array(pendingTransientFacts.values)
        )
        pendingTransientFacts.removeAll()
        transport?.send(envelope)
    }

    private func merge(
        _ envelope: ReplicationEnvelope,
        orbitAnimationDuration: TimeInterval? = nil
    ) {
        var affectedCards: Set<ClinicalCardID> = []
        var didChangeOrbit = false

        for incomingFact in envelope.facts {
            if let currentFact = facts[incomingFact.id],
               incomingFact.version <= currentFact.version {
                continue
            }
            facts[incomingFact.id] = incomingFact

            switch incomingFact.id {
            case .cardExpansion(let cardID),
                 .cardPosition(let cardID),
                 .abbreviationSelection(let cardID):
                affectedCards.insert(cardID)
            case .dashboardOrder:
                materializeDashboardOrder()
            case .orbit:
                didChangeOrbit = true
            }
        }

        if didChangeOrbit {
            materializeOrbit(animationDuration: orbitAnimationDuration)
        }

        for cardID in affectedCards {
            materializeCard(cardID)
        }
    }

    private func materializeCard(_ cardID: ClinicalCardID) {
        if let expansionFact = facts[.cardExpansion(cardID)],
           case .cardExpansion(let isExpanded) = expansionFact.value {
            sharedCardState.setExpansionState(isExpanded, for: cardID)
        }

        if let positionFact = facts[.cardPosition(cardID)],
           case .cardPosition(let position) = positionFact.value {
            sharedCardState.setPosition(position, for: cardID)
        }

        guard let selectionFact = facts[.abbreviationSelection(cardID)],
              case .abbreviationSelection(let selection) = selectionFact.value else {
            return
        }
        sharedCardState.setAbbreviationSelection(selection, for: cardID)
    }

    private func materializeDashboardOrder() {
        guard let orderFact = facts[.dashboardOrder],
              case .dashboardOrder(let order) = orderFact.value else {
            return
        }
        handoverViewModel.applySectionOrder(order)
    }

    private func materializeOrbit(animationDuration: TimeInterval?) {
        guard let orbitFact = facts[.orbit],
              case .orbit(let state, let isFinal) = orbitFact.value else {
            return
        }
        sharedCardState.setOrbitState(
            state,
            animationDuration: animationDuration ?? (
                isFinal
                    ? ImmersiveConfiguration.orbitSnapDuration
                    : ImmersiveConfiguration.orbitRemoteSnapFallbackDuration
            )
        )
    }
}
