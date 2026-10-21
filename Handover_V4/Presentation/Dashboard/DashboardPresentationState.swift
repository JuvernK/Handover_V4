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
/// Starts with every detail section expanded so a fresh handover shows full context immediately.
struct DashboardPresentationState {
    // TODO: After the user's explicit SharePlay implementation go-ahead, synchronize
    // individual/ALL disclosure and inherit it on late join without a mode-entry reset.
    // No restart persistence; scrolling sync is separate. See docs/orbit-source-outlines.md.
    private(set) var expandedSections: Set<ISBARSectionID> = Set(ISBARSectionID.detailSections)
    private(set) var focusedSection: ISBARSectionID? = .introduction

    var allExpanded: Bool {
        expandedSections == Set(ISBARSectionID.detailSections)
    }

    /// Navigation toggles its section open/closed, the same as tapping its header directly;
    /// Introduction only returns to the header, since it has no disclosure of its own.
    mutating func focus(_ section: ISBARSectionID) {
        guard section != .introduction else {
            focusedSection = section
            return
        }
        if isExpanded(section) {
            setExpanded(false, for: section)
        } else {
            setExpanded(true, for: section)
            focusedSection = section
        }
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
