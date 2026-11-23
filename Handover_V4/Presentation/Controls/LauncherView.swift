//
//  LauncherView.swift
//  Handover_V4
//
//  Created by Juvern Khor on 8/9/2026.
//
// Flow: Handover_V4App -> LauncherView -> AppModel + ToggleImmersiveSpaceButton + DashboardView; SharePlayTogether -> Share menu.
// Window transitions belong to the persistent windows because ImmersiveView
// may be tearing down when the immersive space closes.

import SwiftUI

/// Persistent entry, exit, and SharePlay controls beside the immersive dashboard.
struct LauncherView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    // Same key Handover_V4App reads to set colorScheme on every window/scene,
    // so this toggle controls appearance across Dashboard, Spatial, and Orbit.
    @AppStorage("handoverUsesDarkAppearance") private var usesDarkAppearance = true

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
                // The content-sized window would otherwise clip the hint to one truncated line.
                .fixedSize(horizontal: false, vertical: true)

            if appModel.immersiveSpaceState == .open {
                Picker("Presentation mode", selection: Bindable(appModel).presentationMode) {
                    ForEach(PresentationMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.top, 4)
                .transition(.opacity)

                if appModel.presentationMode == .orbit {
                    OrbitNavigationView()
                }

                if appModel.presentationMode == .spatial {
                    SBARRail()
                        .padding(.top, 4)
                        .transition(.opacity)
                }
            }

            VStack(spacing: 12) {
                ToggleImmersiveSpaceButton()
                // Leaving affects only this wearer, so one person can drop out without ending
                // the handover for everyone else.
                Button {
                    Task { @MainActor in
                        if appModel.isSharePlayActive {
                            appModel.leaveSharePlay()
                        } else {
                            await appModel.activateSharePlay()
                        }
                    }
                } label: {
                    Label(
                        appModel.isSharePlayActive ? "Leave SharePlay" : "Start SharePlay",
                        systemImage: appModel.isSharePlayActive ? "shareplay.slash" : "shareplay"
                    )
                }
                .disabled(appModel.isActivatingSharePlay)

                Button {
                    usesDarkAppearance.toggle()
                } label: {
                    Label(usesDarkAppearance ? "Light mode" : "Dark mode",
                          systemImage: usesDarkAppearance ? "sun.max" : "moon")
                }
                .accessibilityValue(usesDarkAppearance ? "Dark mode active" : "Light mode active")
            }
            .padding(.top, 8)
        }
        .padding(40)
        .frame(width: 420)
        .dashboardPanel(cornerRadius: 32)
        // The hidden link exposes the activity in this window's system Share menu,
        // so people can also start SharePlay or nearby sharing from there.
        .background {
            ShareLink(item: SharePlayTogether(), preview: SharePreview("ICU Handover"))
                .hidden()
        }
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
