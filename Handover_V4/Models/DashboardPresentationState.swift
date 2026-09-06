// Flow: PatientDashboardView -> DashboardPresentationState -> section detail disclosure.
import Foundation

/// Five navigation destinations; Introduction is a permanent header.
/// Spatial `SectionID` and SharePlay card identities remain independent.
enum ISBARSectionID: String, CaseIterable, Identifiable {
    case introduction
    case situation
    case background
    case assessment
    case recommendation

    var id: String { rawValue }

    static let detailSections: [Self] = [.situation, .background, .assessment, .recommendation]
}

/// Local disclosure state; summaries remain visible regardless of detail state.
/// Starts with an overview so participants can read all four main points first.
struct DashboardPresentationState {
    private(set) var expandedSections: Set<ISBARSectionID> = []
    private(set) var focusedSection: ISBARSectionID? = .introduction

    var allExpanded: Bool {
        expandedSections == Set(ISBARSectionID.detailSections)
    }

    /// Navigation opens supporting details; Introduction only returns to the header.
    mutating func focus(_ section: ISBARSectionID) {
        focusedSection = section
        if section != .introduction { expandedSections.insert(section) }
    }

    /// ALL affects the four detail groups, never the permanent patient header.
    mutating func toggleAll() {
        if allExpanded {
            expandedSections.removeAll()
            focusedSection = nil
        } else {
            expandedSections = Set(ISBARSectionID.detailSections)
        }
    }

    func isExpanded(_ section: ISBARSectionID) -> Bool {
        expandedSections.contains(section)
    }

    /// Changes one section without closing the supporting details of another.
    mutating func setExpanded(_ expanded: Bool, for section: ISBARSectionID) {
        guard section != .introduction else { return }
        if expanded {
            expandedSections.insert(section)
        } else {
            expandedSections.remove(section)
            if focusedSection == section { focusedSection = nil }
        }
    }
}
