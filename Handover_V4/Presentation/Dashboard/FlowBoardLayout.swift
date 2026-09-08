// Flow: PatientDashboardView -> FlowBoardLayout -> DashboardBoardGeometry -> measured SBAR frames.
import SwiftUI

private struct FlowSectionKey: LayoutValueKey {
    static let defaultValue = ISBARSectionID.situation
}

private struct FlowExpandedKey: LayoutValueKey {
    static let defaultValue = false
}

extension View {
    /// Identifies a board card and whether its details may benefit from two-column measurement.
    func flowSection(_ section: ISBARSectionID, expanded: Bool) -> some View {
        layoutValue(key: FlowSectionKey.self, value: section)
            .layoutValue(key: FlowExpandedKey.self, value: expanded)
    }
}

/// Measures every card at one and two columns, then packs cards in the user-selected order.
/// Sizing and placement share the same geometry so card sizes agree across layout passes.
struct FlowBoardLayout: Layout {
    var columns: Int
    var state: DashboardBoardState
    var gap: CGFloat = 12

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = DashboardBoardGeometry.resolvedWidth(proposal.width, columns: columns, gap: gap)
        return CGSize(width: width, height: frames(width: width, subviews: subviews).values.map(\.maxY).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard bounds.minX.isFinite, bounds.minY.isFinite else { return }
        let width = DashboardBoardGeometry.resolvedWidth(bounds.width, columns: columns, gap: gap)
        let placements = frames(width: width, subviews: subviews)
        for subview in subviews {
            guard let frame = placements[subview[FlowSectionKey.self]] else { continue }
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                          anchor: .topLeading,
                          proposal: ProposedViewSize(width: frame.width, height: frame.height))
        }
    }

    private func frames(width: CGFloat, subviews: Subviews) -> [ISBARSectionID: CGRect] {
        guard columns > 0, width > gap * CGFloat(columns - 1) else { return [:] }
        let narrowWidth = (width - gap * CGFloat(columns - 1)) / CGFloat(columns)
        let wideWidth = columns > 1 ? narrowWidth * 2 + gap : narrowWidth
        let items = subviews.map { subview in
            DashboardBoardGeometry.Item(
                section: subview[FlowSectionKey.self],
                narrowHeight: subview.sizeThatFits(ProposedViewSize(width: narrowWidth, height: nil)).height,
                wideHeight: subview.sizeThatFits(ProposedViewSize(width: wideWidth, height: nil)).height,
                isExpanded: subview[FlowExpandedKey.self]
            )
        }
        return DashboardBoardGeometry.frames(items: items, width: width, columns: columns, gap: gap, state: state)
    }
}
