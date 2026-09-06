//
//  VitalsCard.swift
//  Handover_V4
//
//  Created by Juvern Khor on 30/4/2026.
//

//
//  Dashboard card showing all vital signs for a patient in a 3-column grid.
//
//  This is the visual template every other card will follow:
//    1. CardHeader (grip icon + title)
//    2. Card body with content
//    3. Surrounding card chrome (background, corner radius, border)
//

import SwiftUI

struct VitalsCard: View {
    let patient: Patient

    // 2-column grid — fixed for visual consistency across the dashboard
    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 12, alignment: .top),
        count: 2
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardHeader(title: "Vitals (Past 12 hrs)", systemImage: "waveform.path.ecg")

            Divider()
                .padding(.horizontal, 12)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(patient.vitals) { vital in
                    VitalBox(vital: vital)
                }
            }
            .padding(16)
        }
        .glassBackgroundEffect(in: .rect(cornerRadius: 16))
        .hoverEffect()
    }
}

// MARK: - Preview helpers
//
// Mock patient with realistic vitals so we can preview the card without
// loading the JSON. Once we wire up the JSON loader in Step 5, these
// previews can switch to using real patient data.

#if DEBUG
extension VitalSign {
    // swiftlint:disable:next function_parameter_count
    static func mock(
        label: String,
        value: String,
        unit: String,
        status: VitalStatus,
        history: [Double],
        trend: Trend
    ) -> VitalSign {
        VitalSign(
            id: UUID().uuidString,
            label: label,
            value: value,
            unit: unit,
            status: status,
            timestamp: .now,
            history: history,
            trend: trend
        )
    }
}

extension Patient {
    static var mockAhmad: Patient {
        Patient(
            id: "p1",
            bedNumber: "BED-01",
            mrn: "MRN-202400341",
            name: "Ahmad bin Razali",
            age: 62,
            gender: .male,
            acuity: .stable,
            codeStatus: .fullCode,
            allergies: [Allergy(substance: "Penicillin", reaction: "Rash")],
            diagnosis: "Post-CABG x3",
            avatarImageName: nil,
            icuAdmissionDate: Date().addingTimeInterval(-86400),  // 1 day ago
            vitals: [
                .mock(label: "HR", value: "88", unit: "bpm",
                      status: .normal,
                      history: [97, 95, 92, 90, 88, 86, 85, 87, 89, 90, 89, 88],
                      trend: .down),
                .mock(label: "SpO₂", value: "97", unit: "%",
                      status: .normal,
                      history: [95, 95, 96, 96, 96, 97, 97, 97, 97, 97, 97, 97],
                      trend: .up),
                .mock(label: "Temp", value: "37.1", unit: "°C",
                      status: .normal,
                      history: [37.0, 37.1, 37.2, 37.0, 37.1, 37.1, 37.0, 37.1, 37.1, 37.0, 37.1, 37.1],
                      trend: .stable),
                .mock(label: "RR", value: "16", unit: "/min",
                      status: .normal,
                      history: [22, 20, 19, 18, 18, 17, 17, 16, 17, 16, 16, 16],
                      trend: .down),
                .mock(label: "MAP", value: "87", unit: "mmHg",
                      status: .normal,
                      history: [72, 75, 76, 78, 80, 82, 84, 85, 86, 87, 87, 87],
                      trend: .up)
            ],
            infusions: [],
            lines: [],
            labs: [],
            systems: [],
            plan: [],
            family: FamilyInfo(primaryContact: "Wife", presentAtBedside: true, notes: ""),
            escalation: EscalationInfo(mainConcerns: [], triggers: [], escalateTo: "ICU Registrar")
        )
    }

    static var mockSiti: Patient {
        Patient(
            id: "p2",
            bedNumber: "BED-02",
            mrn: "MRN-202401187",
            name: "Siti Norzahra bt Hamdan",
            age: 47,
            gender: .female,
            acuity: .critical,
            codeStatus: .fullCode,
            allergies: [
                Allergy(substance: "Sulphonamides", reaction: "Anaphylaxis"),
                Allergy(substance: "NSAIDs", reaction: "GI bleed")
            ],
            diagnosis: "Septic shock — RLL pneumonia",
            avatarImageName: nil,
            icuAdmissionDate: Date().addingTimeInterval(-86400 * 4),
            vitals: [
                .mock(label: "HR", value: "112", unit: "bpm",
                      status: .warning,
                      history: [106, 107, 108, 109, 110, 110, 111, 111, 112, 112, 112, 112],
                      trend: .up),
                .mock(label: "SpO₂", value: "91", unit: "%",
                      status: .critical,
                      history: [94, 94, 93, 93, 92, 92, 92, 91, 91, 91, 91, 91],
                      trend: .down),
                .mock(label: "Temp", value: "38.9", unit: "°C",
                      status: .warning,
                      history: [38.4, 38.5, 38.6, 38.6, 38.7, 38.7, 38.8, 38.8, 38.9, 38.9, 38.9, 38.9],
                      trend: .up),
                .mock(label: "RR", value: "28", unit: "/min",
                      status: .critical,
                      history: [25, 25, 26, 26, 27, 27, 27, 28, 28, 28, 28, 28],
                      trend: .up),
                .mock(label: "MAP", value: "70", unit: "mmHg",
                      status: .warning,
                      history: [70, 71, 70, 70, 71, 70, 70, 70, 70, 70, 70, 70],
                      trend: .stable)
            ],
            infusions: [],
            lines: [],
            labs: [],
            systems: [],
            plan: [],
            family: FamilyInfo(primaryContact: "Husband", presentAtBedside: true, notes: ""),
            escalation: EscalationInfo(mainConcerns: [], triggers: [], escalateTo: "ICU Registrar")
        )
    }
}

#endif

// MARK: - Previews

#Preview("Stable patient (Ahmad)") {
    VitalsCard(patient: .mockAhmad)
        .frame(width: 600)
        .padding()
}

#Preview("Critical patient (Siti)") {
    VitalsCard(patient: .mockSiti)
        .frame(width: 600)
        .padding()
}

// #Preview("Narrow window") {
//    VitalsCard(patient: .mockAhmad)
//        .frame(width: 380)
//        .padding()
// }
