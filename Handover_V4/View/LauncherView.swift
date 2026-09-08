//
//  LauncherView.swift
//  Handover_V4
//
//  Created by Juvern Khor on 8/9/2026.
//
// Flow: Handover_V4App -> LauncherView -> AppModel + ToggleImmersiveSpaceButton + DashboardView.
// Window transitions belong to the persistent windows because ImmersiveView
// may be tearing down when the immersive space closes.

import SwiftUI

/// Persistent entry, exit, and SharePlay controls beside the immersive dashboard.
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
