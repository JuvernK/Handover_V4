// Flow: standalone checks -> DashboardPresentationState -> independent detail transitions.
import Foundation

/// Run outside the synchronized app folder so this entry point is not bundled.
@main
struct DashboardPresentationStateChecks {
    static func main() {
        precondition(ISBARSectionID.detailSections == [.situation, .background, .assessment, .recommendation])
        var state = DashboardPresentationState()
        precondition(state.expandedSections == Set(ISBARSectionID.detailSections))
        state.toggleAll()
        precondition(state.expandedSections.isEmpty)
        state.setExpanded(true, for: .assessment)
        state.setExpanded(true, for: .recommendation)
        precondition(state.expandedSections == [.assessment, .recommendation])
        state.setExpanded(false, for: .assessment)
        precondition(state.expandedSections == [.recommendation])
        state.setExpanded(true, for: .assessment)
        precondition(state.isExpanded(.assessment))
        for section in ISBARSectionID.detailSections {
            state.setExpanded(true, for: section)
        }
        precondition(state.expandedSections == Set(ISBARSectionID.detailSections))
        for section in ISBARSectionID.detailSections {
            state.setExpanded(false, for: section)
        }
        precondition(state.expandedSections.isEmpty)
        state.focus(.assessment)
        state.focus(.recommendation)
        precondition(state.expandedSections == [.assessment, .recommendation])
        precondition(state.focusedSection == .recommendation)
        state.setExpanded(false, for: .recommendation)
        precondition(state.focusedSection == nil)
        state.focus(.introduction)
        precondition(state.expandedSections == [.assessment])
        state.setExpanded(true, for: .introduction)
        precondition(!state.isExpanded(.introduction))
        state.toggleAll()
        precondition(state.allExpanded)
        state.toggleAll()
        precondition(state.expandedSections.isEmpty && state.focusedSection == nil)
        state.focus(.assessment)
        precondition(state.expandedSections == [.assessment])
        precondition(state.focusedSection == .assessment)
        // Focusing an already-expanded section collapses it, mirroring a second tap on its
        // rail button — the rail must be able to close a section, not just open it.
        state.focus(.assessment)
        precondition(state.expandedSections.isEmpty)
        precondition(state.focusedSection == nil)
        print("Dashboard presentation checks passed")
    }
}
