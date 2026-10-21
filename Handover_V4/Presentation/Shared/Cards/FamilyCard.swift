// Flow: Patient records -> FamilyCard -> DashboardTheme + SwiftUI presentation.
//
//  FamilyCard.swift
//  Handover_V4
//
//  Dashboard card showing family contact and bedside presence, part of the
//  ISBAR "Recommendation" section.
//

import SwiftUI

struct FamilyCard: View {
    let patient: Patient

    private var family: FamilyInfo {
        patient.family
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardHeader(title: "Family", systemImage: "person.2.fill")

            Divider().padding(.horizontal, 12)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(family.primaryContact)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DashboardTheme.foreground)

                    BedsidePill(presentAtBedside: family.presentAtBedside)
                }

                if !family.notes.isEmpty {
                    Text(family.notes)
                        .font(.system(size: 13))
                        .foregroundStyle(DashboardTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
        }
        .dashboardCardSurface(cornerRadius: 16)
    }
}

private struct BedsidePill: View {
    let presentAtBedside: Bool

    var body: some View {
        Text(presentAtBedside ? "At bedside" : "Not at bedside")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(presentAtBedside ? DashboardTheme.normal : DashboardTheme.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background((presentAtBedside ? DashboardTheme.normal : Color.secondary).opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - Previews

#Preview("Family — Ahmad") {
    FamilyCard(patient: .mockHeader_Ahmad)
        .frame(width: 420)
        .padding()
}
