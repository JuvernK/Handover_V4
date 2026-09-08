// Flow: Patient records -> LineAccessCard -> DashboardTheme + SwiftUI presentation.
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
    @Environment(\.isDashboardSurface) private var isDashboardSurface

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardHeader(title: "Lines & Access", systemImage: "cable.connector", badge: .a)

            Divider().padding(.horizontal, 12)

            if patient.lines.isEmpty {
                EmptyState(message: "No lines or access in situ")
                    .padding(16)
            } else if isDashboardSurface {
                DashboardTileGrid(items: patient.lines) { item in
                    LineTile(item: item)
                }
                .padding(16)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(patient.lines.enumerated()), id: \.element.id) { index, line in
                        LineRow(line: line)

                        if index < patient.lines.count - 1 {
                            Divider().padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .dashboardCardSurface(cornerRadius: 16)
    }
}

/// Associates the device with its location in a single compact visual group.
private struct LineTile: View {
    let item: LineAccess

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.type)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DashboardTheme.foreground)
            Text(item.location)
                .font(.system(size: 13))
                .foregroundStyle(DashboardTheme.secondary)
        }
    }
}

// MARK: - Single line row

private struct LineRow: View {
    let line: LineAccess

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundStyle(DashboardTheme.secondary)

            Text(line.type)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DashboardTheme.foreground)

            Spacer(minLength: 12)

            Text(line.location)
                .font(.system(size: 13))
                .foregroundStyle(DashboardTheme.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Empty state

private struct EmptyState: View {
    let message: String

    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle")
                .foregroundStyle(DashboardTheme.secondary)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(DashboardTheme.secondary)
            Spacer()
        }
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
        .frame(width: 360)
        .padding()
}
