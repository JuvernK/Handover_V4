//
//  Handover_V4App.swift
//  Handover_V4
//
//  Created by Juvern Khor on 29/4/2026.
//

// Flow: Handover_V4App -> LauncherView -> DashboardView -> PatientDashboardView; AppModel -> ImmersiveView.
import SwiftUI
import RealityKit
import RealityKitContent

@main
struct Handover_V4App: App {

    @State private var appModel = AppModel()

    // register so RealityKit can use it at runtime
    init() {
        PointOfInterestComponent.registerComponent()
        PointOfInterestRuntimeComponent.registerComponent()
    }

    var body: some SwiftUI.Scene {
        // Declared first so it's the window the system opens automatically at launch.
        // LauncherView opens the dashboard once the immersive space is open.
        // `Window` (not WindowGroup) so re-opening it via openWindow(id:) brings the
        // same single instance forward instead of stacking a new copy each time.
        Window("Launcher", id: "launcher") {
            LauncherView()
                .environment(appModel)
        }
        .windowStyle(.plain)
        .defaultSize(width: 480, height: 320)

        Window("Dashboard", id: "dashboard") {
            DashboardView(viewModel: appModel.handoverViewModel)
                .environment(appModel)
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
                .onAppear {
                    appModel.immersiveSpaceState = .open
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                }
        }
        .immersionStyle(selection: .constant(.full), in: .full)
    }
}
