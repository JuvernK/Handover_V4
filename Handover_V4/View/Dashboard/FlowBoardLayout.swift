// Flow: PatientDashboardView -> FlowBoardLayout -> masonry placement of SBAR cards.
import SwiftUI

/// Number of columns a card occupies in `FlowBoardLayout`. Defaults to 1.
private struct FlowSpanKey: LayoutValueKey {
    static let defaultValue = 1
}

extension View {
    /// Marks a card as occupying `span` adjacent columns in the enclosing `FlowBoardLayout`.
    func flowSpan(_ span: Int) -> some View {
        layoutValue(key: FlowSpanKey.self, value: span)
    }
}

/// Places cards into whichever column currently has the least height, like Pinterest's
/// masonry grid. A card may span multiple adjacent columns via `flowSpan(_:)`; its top is
/// then the tallest of the columns it spans. Column assignments are recomputed on every
/// layout pass, so a sibling's expand/collapse can move a card to a different column.
struct FlowBoardLayout: Layout {
    var columns: Int
    var gap: CGFloat = 12

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let width = proposal.width, width > 0, columns > 0 else { return .zero }
        let heights = columnHeights(width: width, subviews: subviews) { _, _ in }
        let height = (heights.max() ?? 0) - gap
        return CGSize(width: width, height: max(0, height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard columns > 0, bounds.width > 0 else { return }
        let colWidth = (bounds.width - gap * CGFloat(columns - 1)) / CGFloat(columns)
        _ = columnHeights(width: bounds.width, subviews: subviews) { index, placement in
            let x = bounds.minX + CGFloat(placement.start) * (colWidth + gap)
            let y = bounds.minY + placement.top
            subviews[index].place(at: CGPoint(x: x, y: y),
                                   proposal: ProposedViewSize(width: placement.width, height: placement.height))
        }
    }

    private struct Placement {
        let start: Int
        let top: CGFloat
        let width: CGFloat
        let height: CGFloat
    }

    /// Shared pass for both sizing and placement so column assignment never disagrees between them.
    private func columnHeights(width: CGFloat, subviews: Subviews,
                                onPlace: (Int, Placement) -> Void) -> [CGFloat] {
        let colWidth = (width - gap * CGFloat(columns - 1)) / CGFloat(columns)
        var colHeights = [CGFloat](repeating: 0, count: columns)

        for index in subviews.indices {
            let span = min(max(subviews[index][FlowSpanKey.self], 1), columns)
            let subviewWidth = colWidth * CGFloat(span) + gap * CGFloat(span - 1)
            let size = subviews[index].sizeThatFits(ProposedViewSize(width: subviewWidth, height: nil))

            var bestStart = 0
            var bestTop = CGFloat.infinity
            for start in 0...(columns - span) {
                let top = colHeights[start..<(start + span)].max() ?? 0
                if top < bestTop {
                    bestTop = top
                    bestStart = start
                }
            }

            onPlace(index, Placement(start: bestStart, top: bestTop, width: subviewWidth, height: size.height))
            let bottom = bestTop + size.height + gap
            for i in bestStart..<(bestStart + span) { colHeights[i] = bottom }
        }

        return colHeights
    }
}
