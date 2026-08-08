//
//  SharePlayMessagingType.swift
//  Handover_V4
//
//  Created by Juvern Khor on 22/3/2026.
//

import Foundation
import GroupActivities
import UIKit
import simd // Required for SIMD3


/// A counter system to resolve conflicting message updates from different participants.
struct MessageUpdateCount: Codable, Hashable, Comparable {
    /// The update number, incremented with each color change.
    var count: Int
    /// The ID of the participant who makes the update.
    var participant: Participant.ID

    static func < (lhs: MessageUpdateCount, rhs: MessageUpdateCount) -> Bool {
        if lhs.count != rhs.count {
            return lhs.count < rhs.count
        } else {
            // Use the participant ID as a tiebreaker for deterministic ordering.
            return String(describing: lhs.participant) < String(describing: rhs.participant)
        }
    }
}

enum CardAction: Codable {
    case toggle(isExpanded: Bool)
    case move(position: SIMD3<Float>)
}

/// Model to store message data of a person taps a card (toggle) or moves a card (drag).
struct CardSyncMessage: Codable {
    let cardID: ClinicalCardID
    let action: CardAction
    let updateCount: MessageUpdateCount
}

struct AbbreviationSyncMessage: Codable {
    let cardID: ClinicalCardID
    let action: AbbreviationAction
    let updateCount: MessageUpdateCount
}

struct OrbitSyncMessage: Codable {
    let state: OrbitState
    let updateCount: MessageUpdateCount
    let isFinal: Bool
}

struct DashboardState: Codable {
    let selectedPatientID: String?
    let sectionOrder: [SectionID]
}

enum DashboardAction: Codable {
    case state(DashboardState)
    case selectedPatient(id: String)
    case sectionOrder([SectionID])
}

struct DashboardSyncMessage: Codable {
    let action: DashboardAction
    let updateCount: MessageUpdateCount
}


/// Message sent to late joiners containing the complete current state
struct CatchUpMessage: Codable {
    // A dictionary storing the state of every card/
    let allCardStates: [ClinicalCardID: Bool]
    let allCardPositions: [ClinicalCardID: SIMD3<Float>]
    let cardUpdateCounts: [ClinicalCardID: MessageUpdateCount]
    let abbreviationSelections: [ClinicalCardID: AbbreviationSelection]
    let abbreviationUpdateCounts: [ClinicalCardID: MessageUpdateCount]
    let orbitState: OrbitState
    let orbitUpdateCount: MessageUpdateCount?
    let dashboardState: DashboardState
    let dashboardUpdateCount: MessageUpdateCount?
}
