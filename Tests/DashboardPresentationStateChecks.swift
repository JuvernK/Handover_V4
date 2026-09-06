import Foundation

/// Standalone executable checks for the reading-state model.
/// Kept outside the synchronized app folder so this entry point is not bundled
/// into the application. See docs/dashboard-design.md for the compile command.
@main
struct DashboardPresentationStateChecks {
    static func main() {
        var state = DashboardPresentationState()
        precondition(state.expandedSections == [.situation])
        state.focus(.assessment)
        precondition(state.expandedSections == [.situation, .assessment])
        precondition(state.focusedSection == .assessment)
        state.setExpanded(false, for: .assessment)
        precondition(state.focusedSection == nil)
        precondition(state.isExpanded(.situation))
        state.toggleAll()
        precondition(state.allExpanded)
        state.toggleAll()
        precondition(state.expandedSections.isEmpty && state.focusedSection == nil)
        state.focus(.recommendation)
        precondition(state.expandedSections == [.recommendation])
        precondition(state.focusedSection == .recommendation)
        print("Dashboard presentation checks passed")
    }
}
