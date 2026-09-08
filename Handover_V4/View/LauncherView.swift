//
//  LauncherView.swift
//  Handover_V4
//
//  Created by Juvern Khor on 8/9/2026.
//
//  Shown at launch and after exiting the immersive space. Its only job is
//  getting the user into the ICU immersive space — the dashboard itself
//  only opens once that space is open (see Handover_V4App / DashboardView).
//
//  The launcher dismisses itself and opens the dashboard once immersiveSpaceState
//  flips to .open, driven from here rather than from ImmersiveView — ImmersiveView
//  is mid-teardown during the exit transition, so window calls made from its
//  onAppear/onDisappear are unreliable and can leave the dashboard window stuck open.

import SwiftUI

struct LauncherView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bed.double.fill")
                .font(.system(size: 40))
                .foregroundStyle(DashboardTheme.accent)

            Text("ICU Handover")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Enter the immersive space to view the dashboard.")
                .font(.subheadline)
                .foregroundStyle(DashboardTheme.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                ToggleImmersiveSpaceButton()
                Button {
                    Task { @MainActor in
                        if appModel.isSharePlayActive {
                            appModel.endSession()
                        } else {
                            await appModel.activateSharePlay()
                        }
                    }
                } label: {
                    Label(
                        appModel.isSharePlayActive ? "End SharePlay" : "Start SharePlay",
                        systemImage: appModel.isSharePlayActive ? "shareplay.slash" : "shareplay"
                    )
                }
                .disabled(appModel.isActivatingSharePlay)
            }
            .padding(.top, 8)
        }
        .padding(40)
        .frame(width: 420)
        .dashboardPanel(cornerRadius: 32)
        .alert(
            "SharePlay",
            isPresented: Binding(
                get: { appModel.sharePlayErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        appModel.sharePlayErrorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                appModel.sharePlayErrorMessage = nil
            }
        } message: {
            Text(appModel.sharePlayErrorMessage ?? "")
        }
        .onChange(of: appModel.immersiveSpaceState) { _, newState in
            guard newState == .open else { return }
            openWindow(id: "dashboard")
//            dismissWindow(id: "launcher")
        }
    }
}

#Preview {
    let appModel = AppModel()
    LauncherView()
        .environment(appModel)
}
