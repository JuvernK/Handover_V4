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

            Text(appModel.immersiveSpaceState == .open
                 ? "Choose how to present the handover."
                 : "Enter the immersive space to view the dashboard.")
                .font(.subheadline)
                .foregroundStyle(DashboardTheme.secondary)
                .multilineTextAlignment(.center)

            if appModel.immersiveSpaceState == .open {
                Picker("Presentation mode", selection: Bindable(appModel).presentationMode) {
                    ForEach(AppModel.PresentationMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.top, 4)
                .transition(.opacity)

                if appModel.presentationMode == .spatial {
                    SBARRail()
                        .padding(.top, 4)
                        .transition(.opacity)
                }
            }

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
            if appModel.presentationMode == .dashboard {
                openWindow(id: "dashboard")
            }
//            dismissWindow(id: "launcher")
        }
        // Dashboard mode shows the dashboard window; Spatial and Orbit hide it,
        // keeping the ICU room visible behind the launcher/control window.
        .onChange(of: appModel.presentationMode) { _, newMode in
            guard appModel.immersiveSpaceState == .open else { return }
            if newMode == .dashboard {
                openWindow(id: "dashboard")
            } else {
                dismissWindow(id: "dashboard")
            }
        }
    }
}

/// Group-toggle rail for Spatial mode: each letter expands/collapses every card
/// in that SBAR group at once; ALL does the same across every group. Basic
/// Information isn't part of any group, so it's untouched by either.
private struct SBARRail: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        HStack(spacing: 6) {
            ForEach(SBARGroup.allCases) { group in
                Button(group.letter) {
                    appModel.toggleSBARGroup(group)
                }
                .buttonStyle(.plain)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(group.color)
                .frame(width: 34, height: 34)
                .background(group.color.opacity(0.16), in: RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(DashboardTheme.stroke, lineWidth: 1)
                }
                .hoverEffect(.highlight)
            }

            Button("ALL") {
                appModel.toggleAllSpatialCards()
            }
            .buttonStyle(.plain)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(DashboardTheme.secondary)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(DashboardTheme.glassRaised, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(DashboardTheme.stroke, lineWidth: 1)
            }
            .hoverEffect(.highlight)
        }
    }
}

#Preview {
    let appModel = AppModel()
    LauncherView()
        .environment(appModel)
}
