//
//  DashboardControls.swift
//  Handover_V4
//

import SwiftUI

struct DashboardControls: View {
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
