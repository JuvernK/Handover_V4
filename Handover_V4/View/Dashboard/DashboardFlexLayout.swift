//
//  DashboardFlexLayout.swift
//  Handover_V4
//

import SwiftUI

/// Flexbox-style wrapping layout for dashboard cards.
///
/// Each row fits as many cards as possible using `minimumItemWidth` as its
/// flex basis. Cards may span multiple columns and grow to fill the row.
struct DashboardFlexLayout: Layout {
    let minimumItemWidth: CGFloat
    let spacing: CGFloat
    let rowSpacing: CGFloat

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

            rows.append(
                Row(
                    indices: indices,
                    sizes: sizes,
                    widths: widths,
                    height: sizes.map(\.height).max() ?? 0
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

private nonisolated struct DashboardCardSpanKey: LayoutValueKey {
    static let defaultValue = 1
}

extension View {
    func dashboardCardSpan(_ span: Int) -> some View {
        layoutValue(key: DashboardCardSpanKey.self, value: span)
    }
}
