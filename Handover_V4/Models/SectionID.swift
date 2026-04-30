//
//  SectionID.swift
//  Handover_V4
//
//  Created by Juvern Khor on 30/4/2026.
//
//  Identifies each draggable card on the dashboard.
//
//  The enum carries its own view-building logic via the `view(for:)` method,
//  which keeps the "which card goes with which ID" mapping in one place
//  rather than scattering switch statements through the dashboard view.
//

import SwiftUI
import CoreTransferable
internal import UniformTypeIdentifiers

enum SectionID: String, CaseIterable, Identifiable, Codable, Hashable {
    case vitals
    case infusions
    case lines
    case labs
    case systems
    case plan
    case escalation
    
    var id: String { rawValue }
    
    /// Default order in which cards appear when the dashboard first loads.
    static var defaultOrder: [SectionID] {
        [.vitals, .infusions, .lines, .labs, .systems, .plan, .escalation]
    }
    
    /// Builds the SwiftUI view for this section, given a patient.
    @ViewBuilder
    func view(for patient: Patient) -> some View {
        switch self {
        case .vitals:     VitalsCard(patient: patient)
        case .infusions:  InfusionsCard(patient: patient)
        case .lines:      LinesAccessCard(patient: patient)
        case .labs:       LabsCard(patient: patient)
        case .systems:    SystemsAssessmentCard(patient: patient)
        case .plan:       PlanCard(patient: patient)
        case .escalation: EscalationCard(patient: patient)
        }
    }
    
    /// Human-readable name (currently unused, but useful for accessibility
    /// and any future UI that needs to refer to a section by name).
    var displayName: String {
        switch self {
        case .vitals:     return "Vitals"
        case .infusions:  return "Active Infusions"
        case .lines:      return "Lines & Access"
        case .labs:       return "Abnormal Labs"
        case .systems:    return "Systems Assessment"
        case .plan:       return "Treatment Plan"
        case .escalation: return "Escalation"
        }
    }
}

// MARK: - Transferable conformance
//
// Allows SectionID to be used with SwiftUI's modern .draggable / .dropDestination
// APIs. The transfer payload is just the rawValue String — small, type-safe.

extension SectionID: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .data)
    }
}
