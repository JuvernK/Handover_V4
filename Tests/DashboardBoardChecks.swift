// Flow: standalone checks -> DashboardBoardState + DashboardBoardGeometry -> order transitions and layout probes.
import Foundation
import CoreGraphics

@main
struct DashboardBoardChecks {
    static func main() {
        let sections = ISBARSectionID.detailSections
        var state = DashboardBoardState()
        precondition(state.moveSection(.situation, toPositionOf: .recommendation))
        precondition(state.order == [.background, .assessment, .recommendation, .situation])
        precondition(state.moveSection(.situation, toPositionOf: .background))
        precondition(state.order == sections)
        precondition(state.moveSection(.background, toPositionOf: .assessment))
        precondition(state.order == [.situation, .assessment, .background, .recommendation])
        let unchanged = state.order
        precondition(!state.moveSection(.situation, toPositionOf: .situation))
        precondition(!state.moveSection(.introduction, toPositionOf: .situation))
        precondition(!state.moveSection(.situation, toPositionOf: .introduction))
        precondition(state.order == unchanged)

        // The reported crash occurred during sizing after a drop. Exercise unbounded and
        // invalid probes after an accepted reorder, then check the next real placement.
        let cards = sections.map {
            DashboardBoardGeometry.Item(section: $0, narrowHeight: 900, wideHeight: 500, isExpanded: true)
        }
        for columns in 1...3 {
            for proposedWidth: CGFloat? in [nil, .infinity, -.infinity, .nan, 0, -100, 812, 1400.5] {
                let width = DashboardBoardGeometry.resolvedWidth(proposedWidth, columns: columns, gap: 12)
                precondition(width.isFinite && width > 0)
                let frames = DashboardBoardGeometry.frames(items: cards, width: proposedWidth ?? width,
                                                           columns: columns, gap: 12, state: state)
                checkFrames(frames, width: width)
                let finite = DashboardBoardGeometry.frames(items: cards, width: 812,
                                                           columns: columns, gap: 12, state: state)
                checkFrames(finite, width: 812)
                precondition(state.order == unchanged)
            }
        }
        for section in sections {
            let long = DashboardBoardGeometry.Item(section: section, narrowHeight: 900,
                                                   wideHeight: 500, isExpanded: true)
            precondition(long.span(columns: 2) == 2 && long.span(columns: 1) == 1)
            let collapsed = DashboardBoardGeometry.Item(section: section, narrowHeight: 900,
                                                        wideHeight: 500, isExpanded: false)
            precondition(collapsed.span(columns: 2) == 1)
            let unhelpful = DashboardBoardGeometry.Item(section: section, narrowHeight: 900,
                                                       wideHeight: 880, isExpanded: true)
            precondition(unhelpful.span(columns: 2) == 1)
        }
        for columns in 1...3 {
            for step in 0..<80 {
                let source = sections[step % 4]
                let destination = sections[(step + 1) % 4]
                precondition(state.moveSection(source, toPositionOf: destination))
                let varying = sections.enumerated().map { index, section in
                    let value: Int = step * 139 + index * 211
                    let height = CGFloat(150 + value % 950)
                    return DashboardBoardGeometry.Item(section: section, narrowHeight: height,
                                                        wideHeight: height * 0.6, isExpanded: step % 7 != 0)
                }
                let frames = DashboardBoardGeometry.frames(items: varying, width: 901.75,
                                                           columns: columns, gap: 12, state: state)
                checkFrames(frames, width: 901.75)
                precondition(Set(state.order) == Set(sections))
            }
        }
        print("Dashboard board checks passed")
    }

    static func checkFrames(_ frames: [ISBARSectionID: CGRect], width: CGFloat) {
        precondition(frames.count == 4)
        for (section, frame) in frames {
            precondition(frame.minX.isFinite && frame.minY.isFinite)
            precondition(frame.width.isFinite && frame.height.isFinite)
            precondition(frame.minX >= 0 && frame.minY >= 0 && frame.maxX <= width + 0.01)
            for (other, rect) in frames where other != section {
                precondition(!frame.intersects(rect), "Overlap: \(section), \(other)")
            }
        }
    }
}
