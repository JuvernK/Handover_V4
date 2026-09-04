//
//  DashboardView.swift
//  Handover_V4
//
//  Created by Juvern Khor on 29/4/2026.
//
//
//  Top-level dashboard view. Composed of:
//    - Left panel with PatientHeaderView and reorderable dashboard cards
//    - Right panel with fixed SystemsAssessmentCard
//
//  Drag-and-drop:
//    - Each card in the wrapped layout is both a drag source and a drop target
//    - The whole card is draggable (visionOS gesture model handles tap vs drag)
//    - Dropping card A onto card B moves A into B's current position
//    - The Systems card is excluded from the wrapped layout and not reorderable
//

import SwiftUI

struct DashboardView: View {
    @State var viewModel: HandoverViewModel
    @Environment(AppModel.self) private var appModel
    private let contentPadding: CGFloat = 14
    private let columnSpacing: CGFloat = 16
    private let minimumLeftColumnWidth: CGFloat = 760
    private let systemsPanelWidth: CGFloat = 440

    /// Sections that flow in the flex layout (everything except Systems,
    /// which is rendered in the fixed right panel).
    private var reorderableSections: [SectionID] {
        viewModel.sectionOrder.filter { $0 != .systems }
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = dashboardLayout(for: geometry.size.width)

            ScrollView {
                if let patient = viewModel.patient {
                    HStack(alignment: .top, spacing: columnSpacing) {
                        VStack(spacing: 16) {
                            // Pinned header (always at top, not draggable)
                            PatientHeaderView(patient: patient)
                                .glassBackgroundEffect(in: .rect(cornerRadius: 16))

                            // Reorderable cards
                            DashboardFlexLayout(minimumItemWidth: 280, spacing: 12) {
                                ForEach(reorderableSections) { sectionID in
                                    DraggableCard(
                                        sectionID: sectionID,
                                        patient: patient
                                    )
                                    .dashboardCardSpan(sectionID == .vitals ? 2 : 1)
                                }
                            }
                            .frame(width: layout.leftWidth, alignment: .leading)
                            .animation(.smooth(duration: 0.25), value: viewModel.sectionOrder)
                        }
                        .frame(width: layout.leftWidth, alignment: .topLeading)

                        // Systems Assessment — fixed right panel, not reorderable
                        if viewModel.sectionOrder.contains(.systems) {
                            SystemsAssessmentCard(patient: patient)
                                .frame(width: systemsPanelWidth, alignment: .top)
                        }
                    }
                    .padding(contentPadding)
                    .frame(width: layout.totalWidth, alignment: .leading)
                } else {
                    EmptyDashboardState()
                }
            }
        }
        .dynamicTypeSize(.medium)
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

    private func dashboardLayout(for availableWidth: CGFloat) -> DashboardColumnLayout {
        let safeAvailableWidth = availableWidth.isFinite ? max(availableWidth, 1) : 1
        let horizontalPadding = contentPadding * 2
        let hasSystemsPanel = viewModel.sectionOrder.contains(.systems)
        let rightWidth = hasSystemsPanel ? systemsPanelWidth : 0
        let spacing = hasSystemsPanel ? columnSpacing : 0
        let availableContentWidth = max(
            safeAvailableWidth - horizontalPadding - rightWidth - spacing,
            minimumLeftColumnWidth
        )
        let totalWidth = horizontalPadding + availableContentWidth + rightWidth + spacing

        return DashboardColumnLayout(
            leftWidth: availableContentWidth,
            totalWidth: totalWidth
        )
    }

    private struct DashboardColumnLayout {
        let leftWidth: CGFloat
        let totalWidth: CGFloat
    }
}

// MARK: - Flex layout

/// Flexbox-style wrapping layout for dashboard cards.
///
/// Each row fits as many cards as possible using `minimumItemWidth` as the
/// flex basis. Cards can span multiple columns, then grow to fill the row width.
private struct DashboardFlexLayout: Layout {
    var minimumItemWidth: CGFloat
    var spacing: CGFloat
    var rowSpacing: CGFloat

    init(minimumItemWidth: CGFloat, spacing: CGFloat, rowSpacing: CGFloat? = nil) {
        self.minimumItemWidth = minimumItemWidth
        self.spacing = spacing
        self.rowSpacing = rowSpacing ?? spacing
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let availableWidth = resolvedWidth(proposal.width, subviewCount: subviews.count)
        let rows = makeRows(for: subviews, availableWidth: availableWidth)
        let totalHeight = rows.enumerated().reduce(CGFloat.zero) { height, row in
            height + row.element.height + (row.offset == rows.count - 1 ? 0 : rowSpacing)
        }

        return CGSize(width: availableWidth, height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let rows = makeRows(
            for: subviews,
            availableWidth: resolvedWidth(bounds.width, subviewCount: subviews.count)
        )
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX

            for (position, index) in row.indices.enumerated() {
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(
                        width: row.widths[position],
                        height: row.sizes[position].height
                    )
                )
                x += row.widths[position] + spacing
            }

            y += row.height + rowSpacing
        }
    }

    private func makeRows(for subviews: Subviews, availableWidth: CGFloat) -> [Row] {
        guard !subviews.isEmpty else { return [] }

        let safeWidth = resolvedWidth(availableWidth, subviewCount: subviews.count)
        let columnCount = max(
            1,
            Int((safeWidth + spacing) / (minimumItemWidth + spacing))
        )
        let baseItemWidth = (
            safeWidth - spacing * CGFloat(columnCount - 1)
        ) / CGFloat(columnCount)

        var rows: [Row] = []
        var startIndex = subviews.startIndex

        while startIndex < subviews.endIndex {
            var indices: [Subviews.Index] = []
            var widths: [CGFloat] = []
            var occupiedColumns = 0
            var index = startIndex

            while index < subviews.endIndex {
                let span = cardSpan(for: subviews[index], columnCount: columnCount)

                if !indices.isEmpty, occupiedColumns + span > columnCount {
                    break
                }

                indices.append(index)
                widths.append(width(forSpan: span, baseItemWidth: baseItemWidth))
                occupiedColumns += span
                index = subviews.index(after: index)

                if occupiedColumns >= columnCount {
                    break
                }
            }

            let sizes = indices.enumerated().map { position, index in
                subviews[index].sizeThatFits(
                    ProposedViewSize(width: widths[position], height: nil)
                )
            }
            let rowHeight = sizes.map(\.height).max() ?? 0

            rows.append(
                Row(
                    indices: indices,
                    sizes: sizes,
                    widths: widths,
                    height: rowHeight
                )
            )

            startIndex = index
        }

        return rows
    }

    private func cardSpan(for subview: LayoutSubview, columnCount: Int) -> Int {
        min(max(1, subview[DashboardCardSpanKey.self]), columnCount)
    }

    private func width(forSpan span: Int, baseItemWidth: CGFloat) -> CGFloat {
        baseItemWidth * CGFloat(span) + spacing * CGFloat(span - 1)
    }

    private func resolvedWidth(_ width: CGFloat?, subviewCount: Int) -> CGFloat {
        if let width, width.isFinite, width > 0 {
            return max(width, minimumItemWidth)
        }

        let itemCount = max(1, subviewCount)
        return minimumItemWidth * CGFloat(itemCount) + spacing * CGFloat(itemCount - 1)
    }

    private struct Row {
        let indices: [Subviews.Index]
        let sizes: [CGSize]
        let widths: [CGFloat]
        let height: CGFloat
    }
}

private struct DashboardCardSpanKey: LayoutValueKey {
    static let defaultValue = 1
}

private extension View {
    func dashboardCardSpan(_ span: Int) -> some View {
        layoutValue(key: DashboardCardSpanKey.self, value: span)
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

#Preview("Dashboard — Bed 01") {
    let appModel = AppModel(initialBedNumber: "BED-01")
    DashboardView(viewModel: appModel.handoverViewModel)
        .environment(appModel)
}

#Preview("Dashboard — Bed 02") {
    let appModel = AppModel(initialBedNumber: "BED-02")
    DashboardView(viewModel: appModel.handoverViewModel)
        .environment(appModel)
}

#Preview("Dashboard — Bed 06") {
    let appModel = AppModel(initialBedNumber: "BED-06")
    DashboardView(viewModel: appModel.handoverViewModel)
        .environment(appModel)
}
