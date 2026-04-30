//
//  Enums.swift
//  Handover_V4
//
//  Created by Juvern Khor on 29/4/2026.
//
//  All enum types used across the patient data model.
//

import Foundation

// MARK: - Gender

enum Gender: String, Codable, CaseIterable {
    case male
    case female
}

// MARK: - Acuity Level

/// How critical the patient is overall — drives card colour ring on the dashboard.
enum AcuityLevel: String, Codable, CaseIterable {
    case stable
    case critical
}

// MARK: - Vital Status

/// Status of an individual vital sign or lab result — drives colour coding.
enum VitalStatus: String, Codable, CaseIterable {
    case normal
    case warning
    case critical
}

// MARK: - Trend

/// Direction a lab value is moving — for trend arrows on lab results.
enum Trend: String, Codable, CaseIterable {
    case up
    case down
    case stable
}

// MARK: - Priority

/// Urgency level of a plan/task item.
enum Priority: String, Codable, CaseIterable {
    case urgent
    case routine
}

// MARK: - Body System

/// The body system being assessed in a head-to-toe assessment.
enum BodySystem: String, Codable, CaseIterable {
    case neuro
    case respiratory
    case cardiovascular
    case renal
    case gastrointestinal
    case skin
    case infection
    
    /// Display name for UI.
    var displayName: String {
        switch self {
        case .neuro:            return "Neuro"
        case .respiratory:      return "Respiratory"
        case .cardiovascular:   return "Cardiovascular"
        case .renal:            return "Renal / GU"
        case .gastrointestinal: return "Gastrointestinal"
        case .skin:             return "Skin / Wound"
        case .infection:        return "Infection"
        }
    }
}

// MARK: - Code Status

/// The patient's resuscitation status. Uses associated value for unusual cases
/// like advance directives that don't fit the standard categories.
enum CodeStatus: Codable, Hashable {
    case fullCode
    case dnr
    case custom(String)
    
    /// Display string for the UI.
    var displayText: String {
        switch self {
        case .fullCode:         return "Full Code"
        case .dnr:              return "DNR"
        case .custom(let text): return text
        }
    }
    
    // MARK: Codable conformance
    // Encodes as { "type": "fullCode" } / { "type": "dnr" } / { "type": "custom", "details": "..." }
    
    private enum CodingKeys: String, CodingKey {
        case type, details
    }
    
    private enum CodeStatusType: String, Codable {
        case fullCode, dnr, custom
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(CodeStatusType.self, forKey: .type)
        switch type {
        case .fullCode: self = .fullCode
        case .dnr:      self = .dnr
        case .custom:
            let details = try container.decode(String.self, forKey: .details)
            self = .custom(details)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .fullCode: try container.encode(CodeStatusType.fullCode, forKey: .type)
        case .dnr:      try container.encode(CodeStatusType.dnr, forKey: .type)
        case .custom(let details):
            try container.encode(CodeStatusType.custom, forKey: .type)
            try container.encode(details, forKey: .details)
        }
    }
}
