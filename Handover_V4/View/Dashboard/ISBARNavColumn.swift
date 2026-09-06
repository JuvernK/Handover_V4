// Flow: ISBARNavColumn -> DashboardPresentationState -> PatientDashboardView scrolling.
import SwiftUI

/// Persistent shortcuts preserve the original ISBAR navigation alongside the systems panel.
struct ISBARNavColumn: View {
    @Binding var presentation: DashboardPresentationState
    var isHorizontal = false
    let onFocus: (ISBARSectionID) -> Void

    var body: some View {
        let layout = isHorizontal
            ? AnyLayout(HStackLayout(spacing: 10))
            : AnyLayout(VStackLayout(spacing: 10))
        layout {
            ForEach(ISBARSectionID.allCases) { section in
                Button {
                    withAnimation(.snappy(duration: 0.25)) {
                        presentation.focus(section)
                        onFocus(section)
                    }
                } label: {
                    Text(section.letter)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(isHighlighted(section) ? DashboardTheme.accent : DashboardTheme.secondary)
                        .frame(width: 44, height: 44)
                        .background(isHighlighted(section) ? DashboardTheme.accentSoft : DashboardTheme.glassRaised,
                                    in: .rect(cornerRadius: 14))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(DashboardTheme.stroke, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .hoverEffect(.highlight)
                .accessibilityLabel(section.title)
                .accessibilityValue(presentation.focusedSection == section ? "Selected" : "")
            }
            if !isHorizontal { Divider().frame(width: 24).padding(.vertical, 4) }
            Button {
                withAnimation(.snappy(duration: 0.25)) { presentation.toggleAll() }
            } label: {
                Text("ALL")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DashboardTheme.secondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .hoverEffect(.highlight)
            .accessibilityLabel(presentation.allExpanded ? "Collapse all sections" : "Expand all sections")
        }
        .padding(16)
        .dashboardPanel(cornerRadius: 26)
    }

    private func isHighlighted(_ section: ISBARSectionID) -> Bool {
        presentation.isExpanded(section) || presentation.focusedSection == section
    }
}
