//
//  Handover_V4App.swift
//  Handover_V4
//
//  Created by Juvern Khor on 29/4/2026.
//

import SwiftUI
import RealityKit
import RealityKitContent

@main
struct Handover_V4App: App {
    
    @State private var appModel = AppModel()
    @State private var avPlayerViewModel = AVPlayerViewModel()
    
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
        .defaultSize(width: 1000, height: 1100)
        
        // Controls window (used & visible during immersive space)
            WindowGroup(id: "controls") {
                ImmersiveControlsView()
                    .environment(appModel)
            }
            .defaultSize(width: 320, height: 100)  // just the buttons
            .windowResizability(.contentSize)        // sized to its content
        
        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environment(appModel)
                .environment(appModel.handoverViewModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                    avPlayerViewModel.play()
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                    avPlayerViewModel.reset()
                }
        }
        .immersionStyle(selection: .constant(.full), in: .full)
    }
}
