//
//  PointOfInterestMapper.swift
//  Handover_V4
//

import Foundation

enum PointOfInterestDestination {
    case basicInformation
    case section(SectionID)
    case unknown

    var cardID: ClinicalCardID? {
        switch self {
        case .basicInformation:
            return .basicInformation
        case .section(let sectionID):
            return .section(sectionID)
        case .unknown:
            return nil
        }
    }
}

enum PointOfInterestMapper {
    static func destination(for name: String) -> PointOfInterestDestination {
        let normalizedName = normalize(name)

        guard let cardID = ClinicalCardID(canonicalName: normalizedName) else {
            return .unknown
        }
        switch cardID {
        case .basicInformation:
            return .basicInformation
        case .section(let section):
            return .section(section)
        }
    }

    static func normalize(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }
}
