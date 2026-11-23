// Flow: LauncherView -> ToggleImmersiveSpaceButton -> AppModel.wantsImmersion (shared) -> open/dismiss ImmersiveSpace.
//
//  ToggleImmersiveSpaceButton.swift
//  Handover_V4
//
//  Created by Juvern Khor on 29/4/2026.
//

import SwiftUI

/// Enters or exits the ICU, and keeps the actual immersive space matching `wantsImmersion`.
/// The intent is shared through SharePlay, so a peer entering or exiting moves everyone;
/// this view lives in the persistent launcher, which can still act while the space tears down.
struct ToggleImmersiveSpaceButton: View {

    @Environment(AppModel.self) private var appModel

    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    /// Set when opening fails, so a failure here neither retries forever nor closes the ICU
    /// for peers. Cleared by the next local request or shared change.
    @State private var openingFailed = false

    var body: some View {
        Button {
            openingFailed = false
            appModel.wantsImmersion = appModel.immersiveSpaceState != .open
            Task { await matchImmersiveSpace() }
        } label: {
            Text(appModel.immersiveSpaceState == .open ? "Exit ICU Immersive Space" : "Enter ICU Immersive Space")
        }
        .disabled(appModel.immersiveSpaceState == .inTransition)
        .animation(.none, value: 0)
        .fontWeight(.semibold)
        .onChange(of: appModel.wantsImmersion) {
            openingFailed = false
            Task { await matchImmersiveSpace() }
        }
        // A request that arrives mid-transition is applied once the transition ends.
        .onChange(of: appModel.immersiveSpaceState) {
            Task { await matchImmersiveSpace() }
        }
    }

    private func matchImmersiveSpace() async {
        switch (appModel.wantsImmersion, appModel.immersiveSpaceState) {
        case (true, .closed) where !openingFailed:
            appModel.immersiveSpaceState = .inTransition
            switch await openImmersiveSpace(id: appModel.immersiveSpaceID) {
            case .opened:
                // ImmersiveView.onAppear sets .open, since several paths can reach it.
                break
            case .userCancelled, .error:
                fallthrough
            @unknown default:
                openingFailed = true
                appModel.immersiveSpaceState = .closed
            }

        case (false, .open):
            appModel.immersiveSpaceState = .inTransition
            // AppModel.immersiveSpaceDidClose sets .closed from ImmersiveView.onDisappear.
            await dismissImmersiveSpace()

        default:
            break
        }
    }
}
