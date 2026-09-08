// Flow: DashboardView -> PatientDashboardView -> ISBAR navigation + patient summaries + systems assessment.
import SwiftUI

/// Owns a masonry SBAR board, with a pinned introduction and separate systems reader.
struct PatientDashboardView: View {
    let patient: Patient
    @State private var presentation = DashboardPresentationState()
    @State private var navigationRequest: ISBARSectionID?
    @State private var systemsContentHeight: CGFloat = 0
    /// Drag-to-reorder swaps positions within this array; the masonry board renders in this
    /// order, so a swap here is what actually moves cards. Not persisted across app launches.
    @State private var sectionOrder = ISBARSectionID.detailSections

    private let systemsOverlap: CGFloat = 26

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                // The rail + shared header/board panel + floating systems panel composition holds
                // down to whatever width still leaves the board a readable single column; the systems
                // panel's fixed 400pt width can't shrink further, so only below that floor — or when
                // the window is too short for a pinned header — does the layout switch to the plainer
                // single-scroll fallback with an inline systems card and a horizontal rail.
                let boardWidth = geometry.size.width - 84 - 8 - 400 - 28
                let isWide = geometry.size.height >= 650 && boardWidth >= 280
                Group {
                    if isWide {
                        HStack(alignment: .top, spacing: 8) {
                            navigation(isHorizontal: false)
                                .frame(width: 84)
                                .frame(maxHeight: .infinity, alignment: .center)

                            HStack(alignment: .top, spacing: -systemsOverlap) {
                                VStack(spacing: 0) {
                                    patientHeader
                                        .padding(.trailing, systemsOverlap)
                                    Divider().padding(.horizontal, 20)
                                    ScrollView {
                                        sectionBoard(availableWidth: boardWidth)
                                            .padding(12)
                                            .padding(.trailing, systemsOverlap)
                                    }
                                    .scrollBounceBehavior(.basedOnSize)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                                .dashboardPanel(cornerRadius: 28)

                                systemsPanel(availableHeight: geometry.size.height)
                            }
                        }
                        .padding(14)
                    } else {
                        // One scroll region keeps short windows fully reachable.
                        ScrollView {
                            VStack(spacing: 16) {
                                PatientHeaderView(patient: patient)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .dashboardPanel(cornerRadius: 28)
                                    .id(ISBARSectionID.introduction)
                                ScrollView(.horizontal) {
                                    navigation(isHorizontal: true)
                                }
                                ForEach(sectionOrder) { section in
                                    sectionView(section)
                                    if section == .assessment {
                                        systems.padding(16).dashboardPanel(cornerRadius: 28)
                                    }
                                }
                            }
                            .padding(18)
                        }
                        .padding(14)
                    }
                }
                .task(id: navigationRequest) {
                    guard let destination = navigationRequest else { return }
                    // Wait for expanded content to enter layout before finding its anchor.
                    await Task.yield()
                    guard !Task.isCancelled else { return }
                    withAnimation(.snappy(duration: 0.25)) {
                        // Introduction is already pinned in wide windows; return the reader to the top.
                        proxy.scrollTo(isWide && destination == .introduction ? ISBARSectionID.situation : destination,
                                       anchor: .top)
                    }
                    navigationRequest = nil
                }
            }
        }
        .environment(\.isDashboardSurface, true)
        .foregroundStyle(DashboardTheme.foreground)
        .tint(DashboardTheme.accent)
    }

    /// Overlaps only the reader's reserved edge, keeping text and disclosure targets clear.
    /// Short assessments hug their content; longer ones scroll within a separate height limit.
    private func systemsPanel(availableHeight: CGFloat) -> some View {
        let maximumHeight = min(720, availableHeight - 120)
        return ScrollView {
            systems
                .padding(16)
                .onGeometryChange(for: CGFloat.self) { geometry in
                    geometry.size.height
                } action: { height in
                    systemsContentHeight = height
                }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(width: 400,
               height: systemsContentHeight > 0 ? min(systemsContentHeight, maximumHeight) : maximumHeight)
        .dashboardPanel(cornerRadius: 28)
        .padding(.top, 46)
        // Native glass needs physical separation where the two pane surfaces overlap.
        .offset(z: 12)
        .zIndex(1)
    }

    private func navigation(isHorizontal: Bool) -> some View {
        ISBARNavColumn(presentation: $presentation, isHorizontal: isHorizontal) { destination in
            navigationRequest = destination
        }
    }

    private var patientHeader: some View {
        PatientHeaderView(patient: patient)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var systems: some View {
        SystemsAssessmentCard(patient: patient, isHandoverSidebar: true)
    }

    /// Masonry board: cards drop into whichever column has the least height so far, and can
    /// change column when a sibling's expand/collapse frees or claims space. Assessment always
    /// spans two columns — it carries vitals/labs/infusion grids that need the extra width — and
    /// automatically clamps to one column's width once there's only one column to give it.
    /// Three columns once there is enough room, two is the normal case, one when narrow.
    /// Cards render in `sectionOrder`, which the user can change by dragging a card's grip handle
    /// onto another card to swap their positions.
    private func sectionBoard(availableWidth: CGFloat) -> some View {
        let columns: Int
        if availableWidth > 1400 { columns = 3 }
        else if availableWidth > 600 { columns = 2 }
        else { columns = 1 }
        return FlowBoardLayout(columns: columns, gap: 12) {
            ForEach(sectionOrder) { section in
                sectionView(section)
                    .flowSpan(section == .assessment ? 2 : 1)
            }
        }
    }

    private func sectionView(_ section: ISBARSectionID) -> some View {
        ISBARSectionView(
            section: section,
            patient: patient,
            isFocused: presentation.focusedSection == section,
            isExpanded: Binding(
                get: { presentation.isExpanded(section) },
                set: { presentation.setExpanded($0, for: section) }
            ),
            onSwap: { dragged in
                withAnimation(.snappy(duration: 0.3)) { swapPositions(dragged, section) }
            }
        )
        .id(section)
    }

    private func swapPositions(_ a: ISBARSectionID, _ b: ISBARSectionID) {
        guard a != b,
              let indexA = sectionOrder.firstIndex(of: a),
              let indexB = sectionOrder.firstIndex(of: b) else { return }
        sectionOrder.swapAt(indexA, indexB)
    }
}

// MARK: - Navigation shortcuts

/// Persistent shortcuts preserve the original ISBAR navigation alongside the systems panel.
private struct ISBARNavColumn: View {
    @Binding var presentation: DashboardPresentationState
    var isHorizontal = false
    let onFocus: (ISBARSectionID) -> Void

    var body: some View {
        let layout = isHorizontal
            ? AnyLayout(HStackLayout(spacing: 10))
            : AnyLayout(VStackLayout(spacing: 10))
        layout {
            ForEach(ISBARSectionID.detailSections) { section in
                Button {
                    withAnimation(.snappy(duration: 0.25)) {
                        presentation.focus(section)
                        onFocus(section)
                    }
                } label: {
                    Text(section.letter)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(isHighlighted(section) ? DashboardTheme.accent : DashboardTheme.secondary)
                        .frame(width: 60, height: 60)
                        .background(isHighlighted(section) ? DashboardTheme.accentSoft : DashboardTheme.glassRaised,
                                    in: .rect(cornerRadius: 18))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18)
                                .strokeBorder(DashboardTheme.stroke, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .contentShape(.interaction, RoundedRectangle(cornerRadius: 18))
                .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 18))
                .hoverEffect(.highlight)
                .accessibilityLabel(section.title)
                .accessibilityValue(presentation.focusedSection == section ? "Selected" : "")
            }
            if !isHorizontal { Divider().frame(width: 24).padding(.vertical, 4) }
            Button {
                withAnimation(.snappy(duration: 0.25)) { presentation.toggleAll() }
            } label: {
                Text("ALL")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DashboardTheme.secondary)
                    .frame(width: 60, height: 60)
                    .background(DashboardTheme.glassRaised, in: .rect(cornerRadius: 18))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(DashboardTheme.stroke, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .contentShape(.interaction, RoundedRectangle(cornerRadius: 18))
            .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 18))
            .hoverEffect(.highlight)
            .accessibilityLabel(presentation.allExpanded ? "Collapse all sections" : "Expand all sections")
        }
        .padding(12)
        .dashboardPanel(cornerRadius: 26)
    }

    private func isHighlighted(_ section: ISBARSectionID) -> Bool {
        presentation.isExpanded(section) || presentation.focusedSection == section
    }
}

// MARK: - Section presentation

private extension ISBARSectionID {
    var letter: String {
        String(title.prefix(1))
    }

    var title: String {
        switch self {
        case .introduction: return "Introduction"
        case .situation: return "Situation"
        case .background: return "Background"
        case .assessment: return "Assessment"
        case .recommendation: return "Recommendation"
        }
    }

    /// A missing or blank authored summary is explicit, never inferred from partial records.
    func summary(for patient: Patient) -> String {
        let summary: String?
        switch self {
        case .introduction: summary = patient.diagnosis
        case .situation: summary = patient.handoverSummaries?.situation
        case .background: summary = patient.handoverSummaries?.background
        case .assessment: summary = patient.handoverSummaries?.assessment
        case .recommendation: summary = patient.handoverSummaries?.recommendation
        }
        guard let summary = summary?.trimmingCharacters(in: .whitespacesAndNewlines),
              !summary.isEmpty else { return "No handover summary recorded." }
        return summary
    }

    /// Systems occupy the side column; current vitals support the Assessment summary.
    @ViewBuilder
    func content(for patient: Patient) -> some View {
        switch self {
        case .introduction:
            PatientHeaderView(patient: patient)
        case .situation:
            SituationCard(patient: patient)
        case .background:
            RelatedBackgroundCard(patient: patient)
        case .assessment:
            VStack(spacing: 12) {
                VitalsCard(patient: patient)
                LabsCard(patient: patient).id("labs-preview")
                InfusionsCard(patient: patient).id("infusions-preview")
                LinesAccessCard(patient: patient).id("lines-preview")
            }
        case .recommendation:
            VStack(spacing: 12) {
                PlanCard(patient: patient).id("plan-preview")
                EscalationCard(patient: patient)
                FamilyCard(patient: patient)
            }
        }
    }
}

/// Familiar disclosure header with an always-visible patient-specific main point.
/// The summary wraps in full so collapsing details never hides the clinical headline.
/// Dragging the grip handle onto another card swaps the two cards' positions in the board.
private struct ISBARSectionView: View {
    let section: ISBARSectionID
    let patient: Patient
    let isFocused: Bool
    @Binding var isExpanded: Bool
    let onSwap: (ISBARSectionID) -> Void

    @State private var isDropTarget = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The grip handle is a sibling of the Button, not nested inside its label — a
            // draggable view nested inside a tappable one loses the gesture race to the parent's
            // tap recognizer, the same class of bug as the hover-nesting gotcha in this repo's
            // CLAUDE.md. Keeping it outside lets the drag start before the button ever sees a tap.
            HStack(alignment: .top, spacing: 0) {
                Button {
                    withAnimation(.snappy(duration: 0.25)) { isExpanded.toggle() }
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Text(section.letter)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(DashboardTheme.accent)
                            .frame(width: 44, height: 44)
                            .background(DashboardTheme.accentSoft, in: .rect(cornerRadius: 14))
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 7) {
                            Text(section.title)
                                .font(.system(size: 21, weight: .semibold))
                                .accessibilityAddTraits(.isHeader)
                            Text(section.summary(for: patient))
                                .font(.system(size: 16))
                                .foregroundStyle(DashboardTheme.foreground)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .light))
                            .foregroundStyle(DashboardTheme.secondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .padding(.top, 12)
                    }
                    .padding(.vertical, 20)
                    .padding(.leading, 20)
                    .contentShape(.rect(cornerRadius: 26))
                }
                .buttonStyle(.plain)
                .contentShape(.hoverEffect, .rect(cornerRadius: 26))
                .hoverEffect(.highlight)
                .accessibilityLabel("\(section.title). \(section.summary(for: patient))")
                .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")

                // Drag handle: a dedicated grab target, outside the button, so reordering
                // never fights the header's own tap-to-expand gesture.
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DashboardTheme.secondary)
                    .padding(.top, 33)
                    .padding(.trailing, 20)
                    .padding(.leading, 4)
                    .accessibilityHidden(true)
                    .draggable(section.rawValue)
            }

            if isExpanded {
                Divider().padding(.horizontal, 20)
                section.content(for: patient)
                    .padding(16)
            }
        }
        .dashboardPanel(cornerRadius: 26)
        .overlay {
            RoundedRectangle(cornerRadius: 26)
                .strokeBorder(isDropTarget ? DashboardTheme.accent
                              : (isFocused ? DashboardTheme.accent : .clear),
                              lineWidth: isDropTarget ? 2.5 : 1.5)
                .allowsHitTesting(false)
        }
        .dropDestination(for: String.self) { items, _ in
            guard let raw = items.first, let dragged = ISBARSectionID(rawValue: raw) else { return false }
            onSwap(dragged)
            return true
        } isTargeted: { isDropTarget = $0 }
    }
}
