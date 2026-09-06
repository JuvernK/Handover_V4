//
//  DashboardView.swift
//  Handover_V4
//
//  Created by Juvern Khor on 29/4/2026.
//
//  Hosts the summary-first handover and window-specific controls.
//  Patient selection remains configured by AppModel.
//

// Flow: AppModel -> DashboardView -> PatientDashboardView + DashboardControls.
import SwiftUI

struct DashboardView: View {
    @State var viewModel: HandoverViewModel
    @AppStorage("dashboardUsesDarkAppearance") private var usesDarkAppearance = true
    @Environment(AppModel.self) private var appModel

    var body: some View {
        Group {
            if let patient = viewModel.patient {
                PatientDashboardView(patient: patient)
            } else {
                EmptyDashboardState()
                    .dashboardPanel(cornerRadius: 32)
            }
        }
        .tint(DashboardTheme.accent)
        .dynamicTypeSize(.medium)
        .ornament(attachmentAnchor: .scene(.bottom)) {
            DashboardControls(usesDarkAppearance: $usesDarkAppearance)
                .environment(\.colorScheme, usesDarkAppearance ? .dark : .light)
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
        .environment(\.colorScheme, usesDarkAppearance ? .dark : .light)
    }
}

// MARK: - Dashboard controls

private struct DashboardControls: View {
    @Binding var usesDarkAppearance: Bool
    @Environment(AppModel.self) private var appModel

    var body: some View {
        HStack(spacing: 12) {
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

            ToggleImmersiveSpaceButton()

            Button {
                usesDarkAppearance.toggle()
            } label: {
                Label(usesDarkAppearance ? "Light mode" : "Dark mode",
                      systemImage: usesDarkAppearance ? "sun.max" : "moon")
            }
            .accessibilityValue(usesDarkAppearance ? "Dark mode active" : "Light mode active")
        }
        .padding(12)
        .glassBackgroundEffect()
    }
}

// MARK: - Empty state

private struct EmptyDashboardState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bed.double")
                .font(.system(size: 40))
                .foregroundStyle(DashboardTheme.secondary)
            Text("No patient selected")
                .font(.title3)
                .foregroundStyle(DashboardTheme.secondary)
            Text("PatientData.json may not have loaded.")
                .font(.caption)
                .foregroundStyle(DashboardTheme.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

// MARK: - Previews

#Preview("Dashboard — Bed 01") {
    let appModel = AppModel(initialBedNumber: "BED-01")
    DashboardView(viewModel: appModel.handoverViewModel)
        .environment(appModel)
}

#Preview("Dashboard — Bed 02") {
    let appModel = AppModel(initialBedNumber: "BED-02")
    DashboardView(viewModel: appModel.handoverViewModel)
        .environment(appModel)
}

#Preview("Dashboard — Bed 06") {
    let appModel = AppModel(initialBedNumber: "BED-06")
    DashboardView(viewModel: appModel.handoverViewModel)
        .environment(appModel)
}
