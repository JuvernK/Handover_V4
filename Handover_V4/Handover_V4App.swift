//
//  Handover_V4App.swift
//  Handover_V4
//
//  Created by Juvern Khor on 29/4/2026.
//

// Flow: Handover_V4App -> LauncherView -> DashboardView -> PatientDashboardView; AppModel -> ImmersiveView; SharePlay shares the dashboard window.
import SwiftUI
import RealityKit
import RealityKitContent
import GroupActivities

@main
struct Handover_V4App: App {

    @State private var appModel = AppModel()

    // Controls dark/light appearance across all three presentation modes, toggled
    // from the persistent launcher/control window (see LauncherView). @AppStorage
    // shares this single value across every window/scene in the app.
    @AppStorage("handoverUsesDarkAppearance") private var usesDarkAppearance = true

    // register so RealityKit can use it at runtime
    init() {
        PointOfInterestComponent.registerComponent()
        OrbitSlotComponent.registerComponent()
        PointOfInterestRuntimeComponent.registerComponent()
    }

    private var colorScheme: ColorScheme {
        usesDarkAppearance ? .dark : .light
    }

    var body: some SwiftUI.Scene {
        // Declared first so it's the window the system opens automatically at launch.
        // LauncherView opens the dashboard once the immersive space is open.
        // `Window` (not WindowGroup) so re-opening it via openWindow(id:) brings the
        // same single instance forward instead of stacking a new copy each time.
        Window("Launcher", id: "launcher") {
            LauncherView()
                .environment(appModel)
                .environment(\.colorScheme, colorScheme)
        }
        .windowStyle(.plain)
        .windowResizability(.contentSize)
        .defaultSize(width: 480, height: 320)

        Window("Dashboard", id: "dashboard") {
            DashboardView(viewModel: appModel.handoverViewModel)
                .environment(appModel)
                .environment(\.colorScheme, colorScheme)
                // The dashboard is the content being presented, so SharePlay shares this window.
                .groupActivityAssociation(.primary("dashboard"))
        }
        // Individual dashboard panes supply glass, leaving clear space between them.
        .windowStyle(.plain)
        .defaultSize(width: 1440, height: 860)
        .defaultWindowPlacement { _, context in
            // Keep the launcher's immersive exit controls beside the new dashboard.
            guard let launcher = context.windows.first(where: { $0.id == "launcher" }) else {
                return WindowPlacement(size: CGSize(width: 1440, height: 860))
            }
            return WindowPlacement(.trailing(launcher), size: CGSize(width: 1440, height: 860))
        }

        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environment(appModel)
                .environment(appModel.handoverViewModel)
                .environment(\.colorScheme, colorScheme)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                }
                .onDisappear {
                    appModel.immersiveSpaceDidClose()
                }
        }
        .immersionStyle(selection: .constant(.full), in: .full)
    }
}
