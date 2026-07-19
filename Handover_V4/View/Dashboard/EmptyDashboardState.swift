//
//  EmptyDashboardState.swift
//  Handover_V4
//

import SwiftUI

struct EmptyDashboardState: View {
    let hasPatients: Bool
    let loadingErrorMessage: String?

    private var title: String {
        if loadingErrorMessage != nil {
            return "Patient data unavailable"
        }

        return hasPatients ? "No patient selected" : "No patients available"
    }

    private var message: String {
        if let loadingErrorMessage {
            return loadingErrorMessage
        }

        return hasPatients
            ? "Select a patient to view their handover."
            : "The patient data file does not contain any patients."
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bed.double")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.title3)
                .foregroundStyle(.secondary)

            Text(message)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
