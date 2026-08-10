//
//  LineAccessCard.swift
//  Handover_V4
//
//  Created by Juvern Khor on 30/4/2026.
//
//  Dashboard card listing all lines and access devices currently in the patient.
//  Simple two-column layout: type on left, location on right.
//

import SwiftUI

struct LinesAccessCard: View {
    let patient: Patient
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardHeader(title: "Lines & Access", systemImage: "cable.connector")
            
            Divider().padding(.horizontal, 12)
            
            if patient.lines.isEmpty {
                CardEmptyState(
                    systemImage: "checkmark.circle",
                    message: "No lines or access in situ"
                )
                    .padding(16)
            } else {
                DividedRowList(data: patient.lines) { line in
                    LineRow(line: line)
                }
            }
        }
        .cardContainerBackground()
    }
}

// MARK: - Single line row

private struct LineRow: View {
    let line: LineAccess

    private let cardID = ClinicalCardID.section(.lines)
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundStyle(.secondary)
            
            CardClinicalAbbreviationText(
                line.type,
                textID: .itemField(
                    "type",
                    itemID: line.id,
                    in: cardID
                ),
                font: .system(size: 14, weight: .medium),
                foregroundColor: .primary
            )
            
            Spacer(minLength: 12)
            
            CardClinicalAbbreviationText(
                line.location,
                textID: .itemField(
                    "location",
                    itemID: line.id,
                    in: cardID
                ),
                font: .system(size: 13),
                foregroundColor: .secondary
            )
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Previews

#if DEBUG
extension Patient {
    static var mockLines_Ahmad: Patient {
        let p = mockHeader_Ahmad
        return Patient(
            id: p.id, bedNumber: p.bedNumber, mrn: p.mrn, name: p.name,
            age: p.age, gender: p.gender, acuity: p.acuity,
            codeStatus: p.codeStatus, allergies: p.allergies,
            diagnosis: p.diagnosis, avatarImageName: p.avatarImageName,
            icuAdmissionDate: p.icuAdmissionDate,
            vitals: [], infusions: [],
            lines: [
                LineAccess(id: "l1", type: "Radial Arterial Line", location: "Right"),
                LineAccess(id: "l2", type: "Triple-Lumen CVC", location: "Right IJV"),
                LineAccess(id: "l3", type: "Urinary Catheter", location: "Urethral"),
                LineAccess(id: "l4", type: "Chest Drain", location: "Right pleural"),
                LineAccess(id: "l5", type: "Chest Drain", location: "Left pleural")
            ],
            labs: [], systems: [], plan: [],
            family: p.family, escalation: p.escalation
        )
    }
}
#endif

#Preview("Lines — Ahmad") {
    LinesAccessCard(patient: .mockLines_Ahmad)
        .environment(AppModel())
        .frame(width: 360)
        .padding()
}
