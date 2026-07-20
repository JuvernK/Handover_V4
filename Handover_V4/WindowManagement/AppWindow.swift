//
//  AppWindow.swift
//  Handover_V4
//

/// Stable identities for windows that should have only one logical instance.
nonisolated enum AppWindow: String, Codable, Hashable {
    case dashboard
    case immersiveControls

    var sceneID: String {
        switch self {
        case .dashboard:
            return "dashboard"
        case .immersiveControls:
            return "controls"
        }
    }
}
