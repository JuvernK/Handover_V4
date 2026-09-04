//
//  LabsCard.swift
//  Handover_V4
//
//  Created by Juvern Khor on 30/4/2026.
//
//  Dashboard card showing ONLY abnormal lab results (status != .normal).
//
//  Rationale: a patient may have 30+ lab values. Showing all of them is noise.
//  Nurses scan for what's wrong and trending the wrong way — this card surfaces
//  exactly that.
//
//  If all labs are normal, shows "All within normal limits".
//

import SwiftUI

struct LabsCard: View {
    let patient: Patient

    /// Only labs with status .warning or .critical.
    private var abnormalLabs: [LabResult] {
        patient.labs.filter { $0.status != .normal }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardHeader(title: "Abnormal Labs", systemImage: "testtube.2")

            Divider().padding(.horizontal, 12)

            if abnormalLabs.isEmpty {
                AllNormalState()
                    .padding(16)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(abnormalLabs.enumerated()), id: \.element.id) { index, lab in
                        LabRow(lab: lab)

                        if index < abnormalLabs.count - 1 {
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

// MARK: - Single lab row

private struct LabRow: View {
    let lab: LabResult

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Status indicator dot
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            // Lab name
            Text(lab.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            // Value + unit
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(lab.value)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(statusColor)
                Text(lab.unit)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            // Trend arrow (if present)
            trendArrow
                .frame(width: 14)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var statusColor: Color {
        switch lab.status {
        case .normal:   return .green
        case .warning:  return .orange
        case .critical: return .red
        }
    }

    @ViewBuilder
    private var trendArrow: some View {
        if let trend = lab.trend {
            switch trend {
            case .up:
                Image(systemName: "arrow.up")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
            case .down:
                Image(systemName: "arrow.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
            case .stable:
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
        } else {
            Color.clear
        }
    }
}

// MARK: - All-normal state

private struct AllNormalState: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("All labs within normal limits")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

// MARK: - Previews

#if DEBUG
extension Patient {
    static var mockLabs_Ahmad: Patient {
        let p = mockHeader_Ahmad
        return Patient(
            id: p.id, bedNumber: p.bedNumber, mrn: p.mrn, name: p.name,
            age: p.age, gender: p.gender, acuity: p.acuity,
            codeStatus: p.codeStatus, allergies: p.allergies,
            diagnosis: p.diagnosis, avatarImageName: p.avatarImageName,
            icuAdmissionDate: p.icuAdmissionDate,
            vitals: [], infusions: [], lines: [],
            labs: [
                LabResult(id: "lb1", name: "Hb", value: "9.8", unit: "g/dL", status: .warning, trend: .down),
                LabResult(id: "lb2", name: "K+", value: "3.5", unit: "mmol/L", status: .warning, trend: .stable),
                LabResult(id: "lb3", name: "Creatinine", value: "112", unit: "µmol/L", status: .warning, trend: .up),
                LabResult(id: "lb4", name: "Lactate", value: "1.4", unit: "mmol/L", status: .normal, trend: .stable),  // filtered out
                LabResult(id: "lb5", name: "INR", value: "1.6", unit: "", status: .warning, trend: .stable)
            ],
            systems: [], plan: [],
            family: p.family, escalation: p.escalation
        )
    }

    static var mockLabs_Siti: Patient {
        let p = mockHeader_Siti
        return Patient(
            id: p.id, bedNumber: p.bedNumber, mrn: p.mrn, name: p.name,
            age: p.age, gender: p.gender, acuity: p.acuity,
            codeStatus: p.codeStatus, allergies: p.allergies,
            diagnosis: p.diagnosis, avatarImageName: p.avatarImageName,
            icuAdmissionDate: p.icuAdmissionDate,
            vitals: [], infusions: [], lines: [],
            labs: [
                LabResult(id: "lb1", name: "WBC", value: "22.1", unit: "x10⁹/L", status: .critical, trend: .up),
                LabResult(id: "lb2", name: "CRP", value: "310", unit: "mg/L", status: .critical, trend: .up),
                LabResult(id: "lb3", name: "Lactate", value: "3.8", unit: "mmol/L", status: .critical, trend: .up),
                LabResult(id: "lb4", name: "Procalcitonin", value: "45", unit: "ng/mL", status: .critical, trend: .up),
                LabResult(id: "lb5", name: "Creatinine", value: "198", unit: "µmol/L", status: .critical, trend: .up),
                LabResult(id: "lb6", name: "Platelets", value: "88", unit: "x10⁹/L", status: .warning, trend: .down)
            ],
            systems: [], plan: [],
            family: p.family, escalation: p.escalation
        )
    }

    static var mockLabs_AllNormal: Patient {
        let p = mockHeader_Ahmad
        return Patient(
            id: p.id, bedNumber: p.bedNumber, mrn: p.mrn, name: p.name,
            age: p.age, gender: p.gender, acuity: p.acuity,
            codeStatus: p.codeStatus, allergies: p.allergies,
            diagnosis: p.diagnosis, avatarImageName: p.avatarImageName,
            icuAdmissionDate: p.icuAdmissionDate,
            vitals: [], infusions: [], lines: [],
            labs: [
                LabResult(id: "lb1", name: "Hb", value: "13.5", unit: "g/dL", status: .normal, trend: .stable),
                LabResult(id: "lb2", name: "K+", value: "4.2", unit: "mmol/L", status: .normal, trend: .stable)
            ],
            systems: [], plan: [],
            family: p.family, escalation: p.escalation
        )
    }
}
#endif

#Preview("Mixed — Ahmad") {
    LabsCard(patient: .mockLabs_Ahmad)
        .frame(width: 360)
        .padding()
}

#Preview("Critical — Siti") {
    LabsCard(patient: .mockLabs_Siti)
        .frame(width: 360)
        .padding()
}

#Preview("All normal") {
    LabsCard(patient: .mockLabs_AllNormal)
        .frame(width: 360)
        .padding()
}
