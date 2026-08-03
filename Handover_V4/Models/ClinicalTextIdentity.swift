//
//  ClinicalTextIdentity.swift
//  Handover_V4
//

import Foundation

/// Stable identity for a clinical card that can own one abbreviation selection.
enum ClinicalCardID: Hashable {
    case basicInformation
    case section(SectionID)

    var canonicalName: String {
        switch self {
        case .basicInformation:
            return "basic_information"
        case .section(let section):
            return section.rawValue
        }
    }
}

/// Stable semantic identity for one abbreviation-bearing model field.
struct ClinicalTextID: Hashable {
    let cardID: ClinicalCardID
    let rawValue: String

    static func field(
        _ fieldName: String,
        in card: ClinicalCardID
    ) -> ClinicalTextID {
        ClinicalTextID(
            cardID: card,
            rawValue: "\(card.canonicalName).\(fieldName)"
        )
    }

    static func itemField(
        _ fieldName: String,
        itemID: String,
        in card: ClinicalCardID
    ) -> ClinicalTextID {
        ClinicalTextID(
            cardID: card,
            rawValue: "\(card.canonicalName).item.\(itemID).\(fieldName)"
        )
    }

    /// Use for authored source arrays whose elements do not have model IDs.
    /// The source index is stable across participants and is independent of
    /// any later SwiftUI sorting or layout.
    static func sourceItemField(
        _ fieldName: String,
        sourceIndex: Int,
        parentID: String? = nil,
        in card: ClinicalCardID
    ) -> ClinicalTextID {
        let parentComponent = parentID.map { ".item.\($0)" } ?? ""
        return ClinicalTextID(
            cardID: card,
            rawValue:
                "\(card.canonicalName)\(parentComponent).\(fieldName).\(sourceIndex)"
        )
    }
}
