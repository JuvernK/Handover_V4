//
//  InfusionsCard.swift
//  Handover_V4
//
//  Created by Juvern Khor on 30/4/2026.
//
//  Dashboard card listing all active drug infusions.
//
//  High-alert medications (per ISMP definition — vasopressors, insulin,
//  paralytics, anticoagulants) are marked with a small red indicator dot.
//  This is decorative-but-meaningful: it supports safer handover by drawing
//  the eye to drugs that carry the highest risk of harm if mismanaged.
//

import SwiftUI

struct InfusionsCard: View {
    let patient: Patient
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardHeader(title: "Active Infusions", systemImage: "drop.fill")
            
            Divider().padding(.horizontal, 12)
            
            if patient.infusions.isEmpty {
                EmptyState()
                    .padding(16)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(patient.infusions.enumerated()), id: \.element.id) { index, infusion in
                        InfusionRow(infusion: infusion)
                        
                        if index < patient.infusions.count - 1 {
                            Divider().padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .glassBackgroundEffect(in: .rect(cornerRadius: 16))
    }
}

// MARK: - Single infusion row

private struct InfusionRow: View {
    let infusion: Infusion
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // High-alert indicator (or invisible spacer for alignment)
            if infusion.isHighAlert {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
                    .accessibilityLabel("High-alert medication")
            } else {
                Color.clear
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                // Top line: drug name + dose
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(infusion.drugName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    
                    Text(infusion.dose)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Spacer(minLength: 8)
                    
                    Text(infusion.route)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                
                // Purpose (optional, smaller, secondary)
                if !infusion.purpose.isEmpty {
                    Text(infusion.purpose)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Empty state

private struct EmptyState: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "drop")
                .foregroundStyle(.secondary)
            Text("No active infusions")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

// MARK: - Previews

#if DEBUG
extension Patient {
    static var mockInfusions_Ahmad: Patient {
        let p = mockHeader_Ahmad
        return Patient(
            id: p.id, bedNumber: p.bedNumber, mrn: p.mrn, name: p.name,
            age: p.age, gender: p.gender, acuity: p.acuity,
            codeStatus: p.codeStatus, allergies: p.allergies,
            diagnosis: p.diagnosis, avatarImageName: p.avatarImageName,
            icuAdmissionDate: p.icuAdmissionDate,
            vitals: [],
            infusions: [
                Infusion(id: "i1", drugName: "Noradrenaline", dose: "0.05 mcg/kg/min",
                         route: "IV (CVC)", purpose: "Weaning — BP support", isHighAlert: true),
                Infusion(id: "i2", drugName: "Morphine PCA", dose: "1 mg/hr basal",
                         route: "IV", purpose: "Post-op analgesia", isHighAlert: true),
                Infusion(id: "i3", drugName: "Insulin", dose: "2 U/hr",
                         route: "IV", purpose: "BSL target 6-10", isHighAlert: true)
            ],
            lines: [], labs: [], systems: [], plan: [],
            family: p.family, escalation: p.escalation
        )
    }
    
    static var mockInfusions_Siti: Patient {
        let p = mockHeader_Siti
        return Patient(
            id: p.id, bedNumber: p.bedNumber, mrn: p.mrn, name: p.name,
            age: p.age, gender: p.gender, acuity: p.acuity,
            codeStatus: p.codeStatus, allergies: p.allergies,
            diagnosis: p.diagnosis, avatarImageName: p.avatarImageName,
            icuAdmissionDate: p.icuAdmissionDate,
            vitals: [],
            infusions: [
                Infusion(id: "i1", drugName: "Noradrenaline", dose: "0.15 mcg/kg/min",
                         route: "IV (CVC)", purpose: "Vasopressor support", isHighAlert: true),
                Infusion(id: "i2", drugName: "Vasopressin", dose: "0.03 U/min",
                         route: "IV (CVC)", purpose: "Vasopressor support", isHighAlert: true),
                Infusion(id: "i3", drugName: "Meropenem", dose: "1g q8h",
                         route: "IV", purpose: "Antibiotic — Day 1 of 5", isHighAlert: false),
                Infusion(id: "i4", drugName: "Hydrocortisone", dose: "200 mg/24hr",
                         route: "IV infusion", purpose: "Septic shock", isHighAlert: false),
                Infusion(id: "i5", drugName: "Insulin", dose: "4 U/hr",
                         route: "IV", purpose: "BSL control", isHighAlert: true),
                Infusion(id: "i6", drugName: "Propofol", dose: "20 mL/hr",
                         route: "IV", purpose: "Sedation", isHighAlert: true),
                Infusion(id: "i7", drugName: "Fentanyl", dose: "25 mcg/hr",
                         route: "IV", purpose: "Analgesia", isHighAlert: true)
            ],
            lines: [], labs: [], systems: [], plan: [],
            family: p.family, escalation: p.escalation
        )
    }
}
#endif

#Preview("Infusions — Ahmad (3 drugs, all high-alert)") {
    InfusionsCard(patient: .mockInfusions_Ahmad)
        .frame(width: 380)
        .padding()
}

#Preview("Infusions — Siti (7 drugs, mixed)") {
    InfusionsCard(patient: .mockInfusions_Siti)
        .frame(width: 380)
        .padding()
}
