//
//  DashboardView.swift
//  Handover_V4
//
//  Created by Juvern Khor on 29/4/2026.
//
//  Top-level dashboard view. Five collapsible ISBAR sections (Introduction /
//  Situation / Background / Assessment / Recommendation) — see
//  ISBARSection.swift for the section definitions and accordion chrome.
//
//  Hosts reusable PatientDashboardView content and window-specific controls.
//  Patient selection remains configured by AppModel's initial bed number.
//

import SwiftUI

struct DashboardView: View {
    @State var viewModel: HandoverViewModel
    @Environment(AppModel.self) private var appModel

    var body: some View {
        Group {
            if let patient = viewModel.patient {
                PatientDashboardView(patient: patient)
            } else {
                EmptyDashboardState()
            }
        }
        .dynamicTypeSize(.medium)
        .ornament(attachmentAnchor: .scene(.bottom)) {
            DashboardControls()
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
    }
}

// MARK: - Dashboard controls

private struct DashboardControls: View {
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
                .foregroundStyle(.secondary)
            Text("No patient selected")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("PatientData.json may not have loaded.")
                .font(.caption)
                .foregroundStyle(.tertiary)
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
