import Foundation

enum SharedHandoverTransaction {
    case setCardExpansion(ClinicalCardID, isExpanded: Bool)
    case moveCard(ClinicalCardID, to: SIMD3<Float>)
    case toggleAbbreviation(
        AbbreviationSelection,
        in: ClinicalCardID
    )
    case clearAbbreviations(Set<ClinicalCardID>)
}

enum ReplicationFactID: Codable, Hashable {
    case cardExpansion(ClinicalCardID)
    case cardPosition(ClinicalCardID)
    case abbreviationSelection(ClinicalCardID)
}

enum ReplicationFactValue: Codable, Equatable {
    case cardExpansion(Bool)
    case cardPosition(SIMD3<Float>)
    case abbreviationSelection(AbbreviationSelection?)
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
    private var facts: [ReplicationFactID: VersionedReplicationFact] = [:]
    private var disconnectedChanges: Set<ReplicationFactID> = []
    private weak var transport: (any ReplicationTransport)?

    init(
        participantID: UUID = UUID(),
        sharedCardState: SharedCardState
    ) {
        self.participantID = participantID
        self.sharedCardState = sharedCardState
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

        case .clearAbbreviations(let cardIDs):
            guard !cardIDs.isEmpty else { return false }
            changedFacts = cardIDs.map { cardID in
                makeFact(
                    id: .abbreviationSelection(cardID),
                    value: .abbreviationSelection(nil)
                )
            }
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

    private func merge(_ envelope: ReplicationEnvelope) {
        var affectedCards: Set<ClinicalCardID> = []

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
            }
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
}
