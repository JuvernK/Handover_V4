// Flow: HTML reference -> DashboardTheme -> dashboard panels, badges and clinical cards.
import SwiftUI

/// Shared visual tokens from the standalone HTML, kept outside clinical records.
/// Asset variants adapt to the local scheme; light accents deepen for readable contrast.
enum DashboardTheme {
    static let accent = Color("DashboardAccent")
    static let critical = Color("DashboardCritical")
    static let warning = Color("DashboardWarning")
    static let normal = Color("DashboardNormal")
    static let foreground = Color("DashboardForeground")
    static let secondary = Color("DashboardSecondary")
    static let tertiary = Color("DashboardTertiary")
    static let glass = Color("DashboardGlass")
    static let glassRaised = Color("DashboardGlassRaised")
    static let stroke = Color("DashboardStroke")
    static let hairline = Color("DashboardHairline")
    static let panelBase = Color("DashboardPanelBase")
    static let poolStart = Color("DashboardPoolStart")
    static let poolEnd = Color("DashboardPoolEnd")
    static let accentSoft = accent.opacity(0.18)
}

extension EnvironmentValues {
    /// The window supplies its own enclosing glass; immersive cards still need theirs.
    @Entry var isDashboardSurface = false
}

extension View {
    /// Gives a separate pane a scheme-aware wash beneath native glass.
    func dashboardPanel(cornerRadius: CGFloat) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(DashboardTheme.panelBase)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(LinearGradient(
                            colors: [DashboardTheme.poolStart,
                                     DashboardTheme.poolEnd],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                }
        }
        .glassBackgroundEffect(in: .rect(cornerRadius: cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(DashboardTheme.stroke, lineWidth: 1)
                .allowsHitTesting(false)
        }
    }

    /// Avoids stacking system glass inside the dashboard's enclosing pane.
    func dashboardCardSurface(cornerRadius: CGFloat) -> some View {
        modifier(DashboardCardSurface(cornerRadius: cornerRadius))
    }
}

private struct DashboardCardSurface: ViewModifier {
    @Environment(\.isDashboardSurface) private var isDashboardSurface
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if isDashboardSurface {
            content
                .background(DashboardTheme.glass, in: .rect(cornerRadius: cornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(DashboardTheme.hairline, lineWidth: 1)
                        .allowsHitTesting(false)
                }
        } else {
            // Same stroke treatment as the dashboard surface, so Spatial cards read
            // as the same visual system floating in the room rather than bare glass.
            content
                .glassBackgroundEffect(in: .rect(cornerRadius: cornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(DashboardTheme.stroke, lineWidth: 1)
                        .allowsHitTesting(false)
                }
        }
    }
}
