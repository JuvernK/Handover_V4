// Flow: PatientDashboardView -> AppModel -> DashboardBoardState -> shared section order; FlowBoardLayout -> DashboardBoardGeometry -> measured frames.
import Foundation
import CoreGraphics

/// Dashboard section order, shared through SharePlay; measured geometry stays local.
struct DashboardBoardState: Codable, Equatable, Sendable {
    private(set) var order = ISBARSectionID.detailSections

    /// Moves a section to the destination's original index, shifting intervening sections.
    /// Self-drops and non-dashboard identities leave the order unchanged.
    @discardableResult
    mutating func moveSection(_ source: ISBARSectionID, toPositionOf destination: ISBARSectionID) -> Bool {
        guard source != destination, let fromIndex = order.firstIndex(of: source),
              let destinationIndex = order.firstIndex(of: destination) else { return false }
        order.remove(at: fromIndex)
        order.insert(source, at: min(destinationIndex, order.count))
        return true
    }
}

/// Deterministic geometry shared by native layout and standalone regression checks.
/// Width decisions use actual wrapped content height, never a section-name special case.
enum DashboardBoardGeometry {
    struct Item {
        let section: ISBARSectionID
        let narrowHeight: CGFloat
        let wideHeight: CGFloat
        let isExpanded: Bool

        func span(columns: Int) -> Int {
            // Widen only long expanded cards that materially benefit from the extra width.
            columns > 1 && isExpanded && narrowHeight > 560 && wideHeight < narrowHeight * 0.85 ? 2 : 1
        }
    }

    /// Adapts main's DashboardFlexLayout width resolution for the board's fixed column count.
    /// SwiftUI can probe with infinity or an unspecified width; neither is a placement coordinate.
    static func resolvedWidth(_ proposedWidth: CGFloat?, columns: Int, gap: CGFloat) -> CGFloat {
        let count = max(1, columns)
        let spacing = gap.isFinite ? max(0, gap) : 0
        let totalGap = spacing * CGFloat(count - 1)
        if let proposedWidth, proposedWidth.isFinite, proposedWidth > 0 {
            return max(proposedWidth, totalGap + CGFloat(count))
        }
        return 280 * CGFloat(count) + totalGap
    }

    static func frames(items: [Item], width: CGFloat, columns: Int, gap: CGFloat,
                       state: DashboardBoardState) -> [ISBARSectionID: CGRect] {
        guard columns > 0, gap.isFinite, gap >= 0 else { return [:] }
        let width = resolvedWidth(width, columns: columns, gap: gap)
        let columnWidth = (width - gap * CGFloat(columns - 1)) / CGFloat(columns)
        let ordered = state.order.compactMap { section in items.first { $0.section == section } }
        var result: [ISBARSectionID: CGRect] = [:]

        for item in ordered {
            let span = item.span(columns: columns)
            let size = CGSize(width: columnWidth * CGFloat(span) + gap * CGFloat(span - 1),
                              height: span == 2 ? item.wideHeight : item.narrowHeight)
            guard size.height.isFinite, size.height >= 0 else { return [:] }
            let starts = Array(0...(columns - span))
            let candidates = starts.map { column -> CGRect in
                var frame = CGRect(origin: CGPoint(x: CGFloat(column) * (columnWidth + gap),
                                                   y: 0), size: size)
                // Each collision advances below at least one reserved card, so this terminates.
                while let obstacle = result.values.filter({
                    frame.minX < $0.maxX + gap && frame.maxX + gap > $0.minX &&
                    frame.minY < $0.maxY + gap && frame.maxY + gap > $0.minY
                }).min(by: { $0.maxY < $1.maxY }) {
                    frame.origin.y = obstacle.maxY + gap
                }
                return frame
            }
            result[item.section] = candidates.min {
                $0.minY == $1.minY ? $0.minX < $1.minX : $0.minY < $1.minY
            }
        }
        return result
    }
}
