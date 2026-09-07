// Flow: Patient records -> PlanCard -> DashboardTheme + SwiftUI presentation.
//
//  PlanCard.swift
//  Handover_V4
//
//  Created by Juvern Khor on 30/4/2026.
//
//  Dashboard card listing the treatment plan / tasks for the upcoming shift.
//
//  Items are shown in JSON order (which reflects clinical priority as authored
//  by the outgoing nurse — not sorted automatically).
//
//  Urgent tasks get a flame icon prefix; routine tasks no icon.
//  Due times appear on the right when present.
//

import SwiftUI

struct PlanCard: View {
    let patient: Patient
    @Environment(\.isDashboardSurface) private var isDashboardSurface

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardHeader(title: "Treatment Plan", systemImage: "list.bullet.clipboard")

            Divider().padding(.horizontal, 12)

            if patient.plan.isEmpty {
                EmptyState()
                    .padding(16)
            } else if isDashboardSurface {
                DashboardTileGrid(items: patient.plan, minimumWidth: 280) { item in
                    PlanRow(item: item, isTile: true)
                }
                .padding(16)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(patient.plan.enumerated()), id: \.element.id) { index, item in
                        PlanRow(item: item)

                        if index < patient.plan.count - 1 {
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

// MARK: - Single plan item row

private struct PlanRow: View {
    let item: PlanItem
    var isTile = false

    var body: some View {
        if isTile {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    priorityIndicator
                    Text(item.priority == .urgent ? "Urgent" : "Routine")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DashboardTheme.secondary)
                    Spacer(minLength: 8)
                    if let dueTime = item.dueTime {
                        Text(formatTime(dueTime))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(DashboardTheme.secondary)
                    }
                }
                Text(item.task)
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardTheme.foreground)
            }
        } else {
            row
        }
    }

    private var row: some View {
        HStack(alignment: .top, spacing: 10) {
            // Priority indicator (flame for urgent; subtle dot for routine)
            priorityIndicator
                .padding(.top, 2)
                .frame(width: 14)

            // Task text
            Text(item.task)
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.foreground)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            // Due time (if present)
            if let dueTime = item.dueTime {
                Text(formatTime(dueTime))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(DashboardTheme.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.secondary.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var priorityIndicator: some View {
        switch item.priority {
        case .urgent:
            Image(systemName: "flame.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(DashboardTheme.warning)
                .accessibilityLabel("Urgent")
        case .routine:
            Circle()
                .fill(.secondary.opacity(0.4))
                .frame(width: 6, height: 6)
                .accessibilityLabel("Routine")
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Empty state

private struct EmptyState: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "list.bullet.clipboard")
                .foregroundStyle(DashboardTheme.secondary)
            Text("No tasks set")
                .font(.system(size: 13))
                .foregroundStyle(DashboardTheme.secondary)
            Spacer()
        }
    }
}

// MARK: - Previews

#if DEBUG
extension Patient {
    static var mockPlan_Ahmad: Patient {
        let p = mockHeader_Ahmad
        let cal = Calendar.current
        let today = Date()
        let at = { (h: Int, m: Int) -> Date in
            cal.date(bySettingHour: h, minute: m, second: 0, of: today) ?? today
        }
        return Patient(
            id: p.id, bedNumber: p.bedNumber, mrn: p.mrn, name: p.name,
            age: p.age, gender: p.gender, acuity: p.acuity,
            codeStatus: p.codeStatus, allergies: p.allergies,
            diagnosis: p.diagnosis, avatarImageName: p.avatarImageName,
            icuAdmissionDate: p.icuAdmissionDate,
            vitals: [], infusions: [], lines: [], labs: [], systems: [],
            plan: [
                PlanItem(id: "pl1", task: "Wean noradrenaline — target OFF if MAP stable",
                         dueTime: at(10, 0), priority: .urgent),
                PlanItem(id: "pl2", task: "Remove chest drains if drainage <100 mL/24hr",
                         dueTime: nil, priority: .routine),
                PlanItem(id: "pl3", task: "Continue insulin infusion, 2-hourly BSL monitoring",
                         dueTime: nil, priority: .routine),
                PlanItem(id: "pl4", task: "K+ replacement per sliding scale (target >4.0)",
                         dueTime: nil, priority: .urgent),
                PlanItem(id: "pl5", task: "Chest X-ray",
                         dueTime: at(6, 0), priority: .routine),
                PlanItem(id: "pl6", task: "Cardiology review",
                         dueTime: at(8, 0), priority: .routine),
                PlanItem(id: "pl7", task: "Mobilise with physio if haemodynamically stable",
                         dueTime: nil, priority: .routine)
            ],
            family: p.family, escalation: p.escalation
        )
    }
}
#endif

#Preview("Plan — Ahmad") {
    PlanCard(patient: .mockPlan_Ahmad)
        .frame(width: 420)
        .padding()
}
