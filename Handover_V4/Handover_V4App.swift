//
//  Handover_V4App.swift
//  Handover_V4
//
//  Created by Juvern Khor on 29/4/2026.
//

// Flow: Handover_V4App -> DashboardView -> PatientDashboardView; AppModel -> ImmersiveView.
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
        WindowGroup(id: "dashboard") {
            DashboardView(viewModel: appModel.handoverViewModel)
                .environment(appModel)
        }
        // Individual dashboard panes supply glass, leaving clear space between them.
        .windowStyle(.plain)
        .defaultSize(width: 1440, height: 860)

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
