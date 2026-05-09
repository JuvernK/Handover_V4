//
//  DashboardView.swift
//  Handover_V4
//
//  Created by Juvern Khor on 29/4/2026.
//
//
//  Top-level dashboard view. Composed of:
//    - Pinned PatientHeaderView at the top (not draggable)
//    - LazyVGrid of 6 reorderable cards (Systems is rendered separately below)
//    - Full-width SystemsAssessmentCard at the bottom (not draggable)
//
//  Drag-and-drop:
//    - Each card in the grid is both a drag source and a drop target
//    - The whole card is draggable (visionOS gesture model handles tap vs drag)
//    - Dropping card A onto card B moves A into B's current position
//    - The Systems card is excluded from the grid and not reorderable
//

import SwiftUI

struct DashboardView: View {
    @State var viewModel: HandoverViewModel
    @Environment(AppModel.self) private var appModel
    
    /// Adaptive grid: cards reflow into 1, 2, or 3 columns based on window width.
    private let gridColumns = [
        GridItem(.adaptive(minimum: 280), spacing: 12, alignment: .top)
    ]
    
    /// Sections that flow in the adaptive grid (everything except Systems,
    /// which is rendered full-width below the grid).
    private var reorderableSections: [SectionID] {
        viewModel.sectionOrder.filter { $0 != .systems }
    }
    
    var body: some View {
        ScrollView {
            if let patient = viewModel.patient {
                VStack(spacing: 16) {
                    // Pinned header (always at top, not draggable)
                    PatientHeaderView(patient: patient)
                        .glassBackgroundEffect(in: .rect(cornerRadius: 16))
                    
                    // Reorderable cards
                    LazyVGrid(columns: gridColumns, spacing: 12) {
                        ForEach(reorderableSections) { sectionID in
                            DraggableCard(
                                sectionID: sectionID,
                                patient: patient
                            )
                        }
                    }
                    .animation(.smooth(duration: 0.25), value: viewModel.sectionOrder)
                    
                    // Systems Assessment — full-width, not reorderable
                    if viewModel.sectionOrder.contains(.systems) {
                        SystemsAssessmentCard(patient: patient)
                    }
                }
                .padding(14)
            } else {
                EmptyDashboardState()
            }
        }
        .dynamicTypeSize(.small)
        .ornament(attachmentAnchor: .scene(.bottom)) {
            DashboardControls()
        }
        .alert(
            "SharePlay",
            isPresented: Binding(
                get: { appModel.sharePlayErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        appModel.sharePlayErrorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                appModel.sharePlayErrorMessage = nil
            }
        } message: {
            Text(appModel.sharePlayErrorMessage ?? "")
        }
    }
}

// MARK: - Dashboard controls

private struct DashboardControls: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        HStack(spacing: 12) {
            Button {
                Task { @MainActor in
                    if appModel.isSharePlayActive {
                        appModel.endSession()
                    } else {
                        await appModel.activateSharePlay()
                    }
                }
            } label: {
                Label(
                    appModel.isSharePlayActive ? "End SharePlay" : "Start SharePlay",
                    systemImage: appModel.isSharePlayActive ? "shareplay.slash" : "shareplay"
                )
            }
            .disabled(appModel.isActivatingSharePlay)

            ToggleImmersiveSpaceButton()
        }
        .padding(12)
        .glassBackgroundEffect()
    }
}

// MARK: - Draggable card wrapper

/// Wraps a section's card view with drag source + drop destination behaviour.
private struct DraggableCard: View {
    let sectionID: SectionID
    let patient: Patient
    @Environment(AppModel.self) private var appModel
    
    @State private var isTargeted: Bool = false
    
    var body: some View {
        sectionID.view(for: patient)
            .opacity(isTargeted ? 0.6 : 1.0)
            .scaleEffect(isTargeted ? 0.98 : 1.0)
            .animation(.snappy(duration: 0.15), value: isTargeted)
            .draggable(sectionID) {
                // Drag preview — a slightly transparent copy of the card
                sectionID.view(for: patient)
                    .opacity(0.85)
                    .frame(maxWidth: 300)
            }
            .dropDestination(for: SectionID.self) { droppedItems, _ in
                guard let dragged = droppedItems.first else { return false }
                return appModel.moveDashboardSection(dragged, toPositionOf: sectionID, syncChanges: true)
            } isTargeted: { targeted in
                isTargeted = targeted
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
    let appModel = AppModel()
    DashboardView(viewModel: appModel.handoverViewModel)
        .environment(appModel)
}

#Preview("Dashboard — Bed 02 (Siti, critical)") {
    let appModel = AppModel(initialBedNumber: "BED-02")
    DashboardView(viewModel: appModel.handoverViewModel)
        .environment(appModel)
}

#Preview("Dashboard — Bed 06 (Datin Mariam, post-OLT)") {
    let appModel = AppModel(initialBedNumber: "BED-06")
    DashboardView(viewModel: appModel.handoverViewModel)
        .environment(appModel)
}
