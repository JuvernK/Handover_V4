//
//  DashboardView.swift
//  Handover_V4
//
//  Created by Juvern Khor on 29/4/2026.
//
//
//  Top-level dashboard view. Composed of:
//    - Pinned PatientHeaderView at the top (not draggable)
//    - LazyVGrid of 7 cards below, ordered by viewModel.sectionOrder
//
//  Step 5 wires up the static layout. Step 6 will add drag-and-drop on
//  the grip icons.
//

import SwiftUI

struct DashboardView: View {
    @State var viewModel: HandoverViewModel
    
    /// Adaptive grid: cards reflow into 1, 2, or 3 columns based on window width.
    private let gridColumns = [
        GridItem(.adaptive(minimum: 320), spacing: 16, alignment: .top)
    ]
    
    var body: some View {
        ScrollView {
            if let patient = viewModel.patient {
                VStack(spacing: 16) {
                    // Pinned header (always at top, not draggable)
                    PatientHeaderView(patient: patient)
                        .glassBackgroundEffect(in: .rect(cornerRadius: 16))
                    
                    // Reorderable grid of cards
                    LazyVGrid(columns: gridColumns, spacing: 16) {
                        ForEach(viewModel.sectionOrder) { sectionID in
                            sectionID.view(for: patient)
                        }
                    }
                }
                .padding(20)
            } else {
                EmptyDashboardState()
            }
        }
    }
}

// MARK: - Empty state

private struct EmptyDashboardState: View {
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

// MARK: - Previews

#Preview("Dashboard — Bed 01 (Ahmad)") {
    DashboardView(viewModel: HandoverViewModel(initialBedNumber: "BED-01"))
}

#Preview("Dashboard — Bed 02 (Siti, critical)") {
    DashboardView(viewModel: HandoverViewModel(initialBedNumber: "BED-02"))
}

#Preview("Dashboard — Bed 06 (Datin Mariam, post-OLT)") {
    DashboardView(viewModel: HandoverViewModel(initialBedNumber: "BED-06"))
}
