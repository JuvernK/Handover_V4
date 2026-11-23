// Flow: LauncherView mode switch -> AppModel.presentationMode -> SharedHandoverSnapshot + per-mode views.
import Foundation

/// One of three mutually exclusive ways to present a handover in the immersive space.
/// Entering a mode applies its disclosure reset; SharePlay shares the mode with everyone.
enum PresentationMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case dashboard
    case spatial
    case orbit

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .spatial: return "Spatial"
        case .orbit: return "Orbit"
        }
    }
}
