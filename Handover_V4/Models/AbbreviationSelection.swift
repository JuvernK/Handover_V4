//
//  AbbreviationSelection.swift
//  Handover_V4
//

import Foundation

/// Identifies one deterministic occurrence of an Approved Abbreviation.
struct AbbreviationSelection: Codable, Hashable {
    let textID: String
    let glossaryEntryID: String
    let occurrenceIndex: Int
}

/// A deterministic state transition for one card's selected abbreviation.
enum AbbreviationAction: Codable, Equatable {
    case set(AbbreviationSelection?)
}
