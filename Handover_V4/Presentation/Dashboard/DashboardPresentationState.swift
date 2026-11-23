// Flow: PatientDashboardView -> AppModel.dashboard -> DashboardPresentationState -> section detail disclosure + SharePlay snapshot.
import Foundation

/// Five navigation destinations; Introduction is a permanent header.
/// Spatial `SectionID` and Spatial card names remain independent.
enum ISBARSectionID: String, CaseIterable, Identifiable, Codable, Sendable {
    case introduction
    case situation
    case background
    case assessment
    case recommendation

    var id: String { rawValue }

    static let detailSections: [Self] = [.situation, .background, .assessment, .recommendation]
}

/// Disclosure and focus state, shared through SharePlay; summaries remain visible regardless.
/// Starts with every detail section expanded so a fresh handover shows full context immediately.
struct DashboardPresentationState: Codable, Equatable, Sendable {
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
