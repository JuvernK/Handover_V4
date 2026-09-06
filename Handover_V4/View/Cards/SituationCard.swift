//
//  SituationCard.swift
//  Handover_V4
//
//  Dashboard card answering the ISBAR "Situation" question: why the patient
//  is here right now, and what is currently going wrong.
//

import SwiftUI

struct SituationCard: View {
    let patient: Patient

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardHeader(title: "Working Diagnosis", systemImage: "waveform.path.ecg.rectangle")

            Divider().padding(.horizontal, 12)

            VStack(alignment: .leading, spacing: 12) {
                Text(patient.diagnosis)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    StatusPill(
                        text: patient.acuity == .critical ? "Critical acuity" : "Stable acuity",
                        color: patient.acuity == .critical ? .red : .green
                    )
                    StatusPill(
                        text: trajectoryText,
                        color: trajectoryColor
                    )
                }

                if patient.escalation.mainConcerns.isEmpty {
                    Text("No main concerns recorded")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(patient.escalation.mainConcerns.enumerated()), id: \.offset) { _, concern in
                        Label(concern, systemImage: "exclamationmark.triangle")
                            .font(.system(size: 14))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(16)
        }
        .glassBackgroundEffect(in: .rect(cornerRadius: 16))
    }

    private var trajectoryText: String {
        switch patient.trajectory {
        case .improving: return "Improving"
        case .stable: return "Stable"
        case .worsening: return "Worsening"
        }
    }

    private var trajectoryColor: Color {
        switch patient.trajectory {
        case .improving: return .green
        case .stable: return .blue
        case .worsening: return .red
        }
    }
}

private struct StatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.85))
            .clipShape(Capsule())
    }
}

// MARK: - Previews

#Preview("Situation — Ahmad") {
    SituationCard(patient: .mockHeader_Ahmad)
        .frame(width: 420)
        .padding()
}

#Preview("Situation — Siti") {
    SituationCard(patient: .mockHeader_Siti)
        .frame(width: 420)
        .padding()
}
