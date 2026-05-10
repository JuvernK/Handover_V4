//
//  SystemAssessmentCard.swift
//  Handover_V4
//
//  Created by Juvern Khor on 30/4/2026.
//
//  Dashboard card showing the head-to-toe assessment, one row per body system.
//
//  Each system has:
//    - SF Symbol icon (visual scannability)
//    - System name
//    - Summary text
//    - Optional concerns list (small warning lines beneath)
//
//  This is the largest card on the dashboard. It typically spans the full
//  width of the grid rather than fitting in a single column.
//

import SwiftUI

struct SystemsAssessmentCard: View {
    let patient: Patient
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardHeader(title: "Systems Assessment", systemImage: "stethoscope")
            
            Divider().padding(.horizontal, 12)
            
            if patient.systems.isEmpty {
                EmptyState()
                    .padding(16)
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 360), spacing: 12, alignment: .top)
                    ],
                    alignment: .leading,
                    spacing: 4
                ) {
                    ForEach(patient.systems) { system in
                        SystemRow(assessment: system)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .glassBackgroundEffect(in: .rect(cornerRadius: 16))
    }
}

// MARK: - Single system row

private struct SystemRow: View {
    let assessment: SystemAssessment
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // System icon
            Image(systemName: assessment.system.iconName)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(assessment.system.iconColor)
                .frame(width: 28, height: 28)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 6) {
                // System name
                Text(assessment.system.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                
                // Summary text
                Text(assessment.summary)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                
                // Concerns (if any)
                if !assessment.concerns.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(assessment.concerns, id: \.self) { concern in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.orange)
                                    .padding(.top, 3)
                                
                                Text(concern)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.top, 2)
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Empty state

private struct EmptyState: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "stethoscope")
                .foregroundStyle(.secondary)
            Text("No systems assessment recorded")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

// MARK: - BodySystem icon mapping
// Provides SF Symbol icon and tint colour for each body system.

private extension BodySystem {
    var iconName: String {
        switch self {
        case .neuro:            return "brain.head.profile"
        case .respiratory:      return "lungs.fill"
        case .cardiovascular:   return "heart.fill"
        case .renal:            return "drop.fill"
        case .gastrointestinal: return "fork.knife"
        case .skin:             return "hand.raised.fill"
        case .infection:        return "bandage.fill"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .neuro:            return .purple
        case .respiratory:      return .blue
        case .cardiovascular:   return .red
        case .renal:            return .yellow
        case .gastrointestinal: return .brown
        case .skin:             return .pink
        case .infection:        return .green
        }
    }
}

// MARK: - Previews

#if DEBUG
extension Patient {
    static var mockSystems_Ahmad: Patient {
        let p = mockHeader_Ahmad
        return Patient(
            id: p.id, bedNumber: p.bedNumber, mrn: p.mrn, name: p.name,
            age: p.age, gender: p.gender, acuity: p.acuity,
            codeStatus: p.codeStatus, allergies: p.allergies,
            diagnosis: p.diagnosis, avatarImageName: p.avatarImageName,
            icuAdmissionDate: p.icuAdmissionDate,
            vitals: [], infusions: [], lines: [], labs: [],
            systems: [
                SystemAssessment(id: "s1", system: .neuro,
                                 summary: "Alert and oriented x3. Pain score 4/10. Morphine PCA initiated.",
                                 concerns: []),
                SystemAssessment(id: "s2", system: .respiratory,
                                 summary: "Extubated, on face mask O₂ 6L/min. Chest physio started. Bilateral chest drains — serosanguinous fluid.",
                                 concerns: ["Monitor chest drain output for haemothorax"]),
                SystemAssessment(id: "s3", system: .cardiovascular,
                                 summary: "NSR on telemetry. Weaning noradrenaline. Chest drains: R=50 mL, L=60 mL since op.",
                                 concerns: ["Watch for post-op AF"]),
                SystemAssessment(id: "s4", system: .renal,
                                 summary: "UO 0.8 mL/kg/hr. IDC in situ. Cr baseline 98 — mild AKI watch.",
                                 concerns: ["Mild post-op AKI"]),
                SystemAssessment(id: "s5", system: .gastrointestinal,
                                 summary: "NBM. Sips of water tolerated. NGT removed. Bowel sounds present.",
                                 concerns: []),
                SystemAssessment(id: "s6", system: .skin,
                                 summary: "Sternal wound dry, intact. Leg harvest site clean, no ooze.",
                                 concerns: [])
            ],
            plan: [],
            family: p.family, escalation: p.escalation
        )
    }
    
    static var mockSystems_Siti: Patient {
        let p = mockHeader_Siti
        return Patient(
            id: p.id, bedNumber: p.bedNumber, mrn: p.mrn, name: p.name,
            age: p.age, gender: p.gender, acuity: p.acuity,
            codeStatus: p.codeStatus, allergies: p.allergies,
            diagnosis: p.diagnosis, avatarImageName: p.avatarImageName,
            icuAdmissionDate: p.icuAdmissionDate,
            vitals: [], infusions: [], lines: [], labs: [],
            systems: [
                SystemAssessment(id: "s1", system: .neuro,
                                 summary: "Sedated — Propofol 20 mL/hr + Fentanyl 25 mcg/hr. RASS -2. Daily wake-up trial planned at 0600.",
                                 concerns: []),
                SystemAssessment(id: "s2", system: .respiratory,
                                 summary: "Mechanically ventilated. Thick yellow-green secretions, q2h suction. CXR: RLL consolidation. Prone considered if P/F <150.",
                                 concerns: ["Severe pneumonia", "Prone positioning may be required"]),
                SystemAssessment(id: "s3", system: .cardiovascular,
                                 summary: "Tachycardic. On dual vasopressors. Echo yesterday: LVEF 50%, no effusion. Septic source = lungs.",
                                 concerns: ["High vasopressor requirements"]),
                SystemAssessment(id: "s4", system: .renal,
                                 summary: "UO 20 mL/hr (declining). AKI Stage 2. Cr trending up. Nephrology aware — may need CRRT.",
                                 concerns: ["Worsening AKI", "CRRT pending"]),
                SystemAssessment(id: "s5", system: .gastrointestinal,
                                 summary: "NGT in situ. EN at 20 mL/hr (target 60 mL/hr). Omeprazole 40 mg IV OD.",
                                 concerns: []),
                SystemAssessment(id: "s6", system: .skin,
                                 summary: "No pressure injuries. Flowtron boots on. Turn q2h protocol.",
                                 concerns: []),
                SystemAssessment(id: "s7", system: .infection,
                                 summary: "Septic shock — RLL pneumonia. Day 2 Meropenem. Sputum C&S pending.",
                                 concerns: ["Source control critical"])
            ],
            plan: [],
            family: p.family, escalation: p.escalation
        )
    }
}
#endif

#Preview("Systems — Ahmad (6 systems)") {
    SystemsAssessmentCard(patient: .mockSystems_Ahmad)
        .frame(width: 600)
        .padding()
}

#Preview("Systems — Siti (7 systems)") {
    SystemsAssessmentCard(patient: .mockSystems_Siti)
        .frame(width: 600)
        .padding()
}
