//
//  EmptyDashboardState.swift
//  Handover_V4
//

// Generally not in used (for mock only)

import SwiftUI

struct EmptyDashboardState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bed.double")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("No patient selected")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("PatientData.json may not have loaded.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
