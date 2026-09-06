// Flow: Patient records -> EscalationCard -> DashboardTheme + SwiftUI presentation.
//
//  EscalationCard.swift
//  Handover_V4
//
//  Created by Juvern Khor on 30/4/2026.
//
//  Dashboard card showing the patient's main concerns and clinical thresholds
//  that trigger an escalation call.
//
//  This is the most safety-critical card on the dashboard. It uses warning
//  and phone iconography to keep escalation triggers visually distinct, and
//  structures content as:
//    - Main concerns (what to watch for)
//    - "Call X if..." (specific trigger thresholds)
//

import SwiftUI

struct EscalationCard: View {
    let patient: Patient

    private var escalation: EscalationInfo {
        patient.escalation
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardHeader(title: "Escalation", systemImage: "phone.arrow.up.right.fill")

            Divider().padding(.horizontal, 12)

            VStack(alignment: .leading, spacing: 16) {
                // Main concerns
                if !escalation.mainConcerns.isEmpty {
                    ConcernsSection(concerns: escalation.mainConcerns)
                }

                // Call X if...
                if !escalation.triggers.isEmpty {
                    TriggersSection(
                        escalateTo: escalation.escalateTo,
                        triggers: escalation.triggers
                    )
                }
            }
            .padding(16)
        }
        .dashboardCardSurface(cornerRadius: 16)
    }
}

// MARK: - Concerns section

private struct ConcernsSection: View {
    let concerns: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Main concerns")

            VStack(alignment: .leading, spacing: 6) {
                ForEach(concerns, id: \.self) { concern in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DashboardTheme.warning)
                            .padding(.top, 3)

                        Text(concern)
                            .font(.system(size: 13))
                            .foregroundStyle(DashboardTheme.foreground)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

// MARK: - Triggers section

private struct TriggersSection: View {
    let escalateTo: String
    let triggers: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Call \(escalateTo) if:")

            VStack(alignment: .leading, spacing: 6) {
                ForEach(triggers, id: \.self) { trigger in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(DashboardTheme.critical)
                            .padding(.top, 4)

                        Text(trigger)
                            .font(.system(size: 13))
                            .foregroundStyle(DashboardTheme.foreground)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

// MARK: - Reusable section label

private struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(DashboardTheme.secondary)
            .tracking(0.5)
    }
}

// MARK: - Previews

#if DEBUG
extension Patient {
    static var mockEscalation_Ahmad: Patient {
        let p = mockHeader_Ahmad
        return Patient(
            id: p.id, bedNumber: p.bedNumber, mrn: p.mrn, name: p.name,
            age: p.age, gender: p.gender, acuity: p.acuity,
            codeStatus: p.codeStatus, allergies: p.allergies,
            diagnosis: p.diagnosis, avatarImageName: p.avatarImageName,
            icuAdmissionDate: p.icuAdmissionDate,
            vitals: [], infusions: [], lines: [], labs: [], systems: [], plan: [],
            family: p.family,
            escalation: EscalationInfo(
                mainConcerns: [
                    "Monitor for post-op AF",
                    "Watch chest drain output for haemothorax"
                ],
                triggers: [
                    "Sudden increase in chest drain output",
                    "New-onset AF",
                    "Any haemodynamic deterioration"
                ],
                escalateTo: "ICU Registrar"
            )
        )
    }

    static var mockEscalation_Siti: Patient {
        let p = mockHeader_Siti
        return Patient(
            id: p.id, bedNumber: p.bedNumber, mrn: p.mrn, name: p.name,
            age: p.age, gender: p.gender, acuity: p.acuity,
            codeStatus: p.codeStatus, allergies: p.allergies,
            diagnosis: p.diagnosis, avatarImageName: p.avatarImageName,
            icuAdmissionDate: p.icuAdmissionDate,
            vitals: [], infusions: [], lines: [], labs: [], systems: [], plan: [],
            family: p.family,
            escalation: EscalationInfo(
                mainConcerns: [
                    "Worsening renal function",
                    "High vasopressor requirements",
                    "Risk of MODS"
                ],
                triggers: [
                    "Vasopressor requirements increase",
                    "UO drops below 15 mL/hr",
                    "New arrhythmia develops",
                    "SpO₂ deteriorates below 88%"
                ],
                escalateTo: "ICU Consultant"
            )
        )
    }
}
#endif

#Preview("Escalation — Ahmad (stable)") {
    EscalationCard(patient: .mockEscalation_Ahmad)
        .frame(width: 420)
        .padding()
}

#Preview("Escalation — Siti (critical)") {
    EscalationCard(patient: .mockEscalation_Siti)
        .frame(width: 420)
        .padding()
}
