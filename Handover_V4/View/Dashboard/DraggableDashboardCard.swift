//
//  DraggableDashboardCard.swift
//  Handover_V4
//

import SwiftUI

/// Adds dashboard drag-and-drop behavior to a section card.
struct DraggableDashboardCard: View {
    let sectionID: SectionID
    let patient: Patient

    @Environment(AppModel.self) private var appModel
    @State private var isTargeted = false

    var body: some View {
        sectionID.view(for: patient)
            .opacity(isTargeted ? 0.6 : 1.0)
            .scaleEffect(isTargeted ? 0.98 : 1.0)
            .animation(.snappy(duration: 0.15), value: isTargeted)
            .draggable(sectionID) {
                sectionID.view(for: patient)
                    .opacity(0.85)
                    .frame(maxWidth: 300)
            }
            .dropDestination(for: SectionID.self) { droppedItems, _ in
                guard let draggedSection = droppedItems.first else { return false }

                return appModel.moveDashboardSection(
                    draggedSection,
                    toPositionOf: sectionID,
                    syncChanges: true
                )
            } isTargeted: { isTargeted = $0 }
    }
}
