import Foundation

/// The five reading groups, in the order displayed by the dashboard.
///
/// These IDs describe presentation, not patient records. Existing `SectionID`
/// values still identify individual cards in spatial content and SharePlay.
enum ISBARSectionID: String, CaseIterable, Identifiable {
    case introduction
    case situation
    case background
    case assessment
    case recommendation

    var id: String { rawValue }
}

/// Local reading state, independent of clinical records and spatial placement.
///
/// Owned by `PatientDashboardView` using SwiftUI's `@State`. Keeping this a
/// plain value allows the interaction rules to be checked without SwiftUI.
/// Changes are local to that view instance and are not broadcast by SharePlay.
struct DashboardPresentationState {
    /// Several groups may be open at once; Situation is the starting point.
    private(set) var expandedSections: Set<ISBARSectionID> = [.situation]

    /// Last explicitly chosen navigation destination, not keyboard focus or
    /// the section currently visible while manually scrolling.
    /// A non-nil focused section must also be expanded.
    private(set) var focusedSection: ISBARSectionID? = .situation

    var allExpanded: Bool {
        expandedSections.count == ISBARSectionID.allCases.count
    }

    func isExpanded(_ section: ISBARSectionID) -> Bool {
        expandedSections.contains(section)
    }

    /// Applies a section-header toggle without changing other sections.
    /// Closing the focused section clears focus; opening one does not scroll.
    mutating func setExpanded(_ expanded: Bool, for section: ISBARSectionID) {
        if expanded {
            expandedSections.insert(section)
        } else {
            expandedSections.remove(section)
            if focusedSection == section { focusedSection = nil }
        }
    }

    /// Opens a navigation destination, preserving other expanded sections.
    /// The view performs scrolling separately because it owns the layout.
    mutating func focus(_ section: ISBARSectionID) {
        expandedSections.insert(section)
        focusedSection = section
    }

    /// Expands all unless all are already open, then collapses all.
    /// Expanding all preserves existing focus; collapsing all clears it.
    mutating func toggleAll() {
        if allExpanded {
            expandedSections.removeAll()
            focusedSection = nil
        } else {
            expandedSections = Set(ISBARSectionID.allCases)
        }
    }
}
