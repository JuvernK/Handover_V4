//
//  ToggleImmersiveSpaceButton.swift
//  Handover_V4
//
//  Created by Juvern Khor on 29/4/2026.
//

import SwiftUI

struct ImmersiveControlsView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Orbit")
                    .font(.headline)

                // Looks like "<" "End Orbit" ">"
                HStack(spacing: 12) {
                    Button {
                        appModel.moveOrbitFocus(by: 1)
                    } label: {
                        Label("Previous card", systemImage: "chevron.left")
                            .labelStyle(.iconOnly)
                            .frame(width: 60, height: 60)
                    }
                    .disabled(!appModel.orbitState.isActive)

                    Button {
                        appModel.setOrbitEnabled(!appModel.orbitState.isActive)
                    } label: {
                        Label(
                            appModel.orbitState.isActive ? "End Orbit" : "Start Orbit",
                            systemImage: appModel.orbitState.isActive
                                ? "circle.dashed.inset.filled"
                                : "circle.dashed"
                        )
                        .frame(maxWidth: .infinity, minHeight: 60)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        appModel.moveOrbitFocus(by: -1)
                    } label: {
                        Label("Next card", systemImage: "chevron.right")
                            .labelStyle(.iconOnly)
                            .frame(width: 60, height: 60)
                    }
                    .disabled(!appModel.orbitState.isActive)
                }
            }

            Divider()

            ToggleImmersiveSpaceButton(isFullWidth: true)
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                .background(
                    Color(red: 0.29, green: 0.33, blue: 0.38)
                        .opacity(0.55),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .glassBackgroundEffect(in: .rect(cornerRadius: 16))
        }
        .padding()
        .frame(width: 420)
        .glassBackgroundEffect()
    }
}

struct ToggleImmersiveSpaceButton: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var isPerformingTransition = false
    var isFullWidth = false

    var body: some View {
        Button {
            guard !isPerformingTransition else { return }
            isPerformingTransition = true

            Task { @MainActor in
                defer { isPerformingTransition = false }

                switch appModel.immersiveSpaceState {
                case .open:
                    appModel.immersiveSpaceState = .inTransition

                    // Close every controls window with this logical identity before
                    // ImmersiveView.onDisappear changes the shared state to closed.
                    dismissWindow(
                        id: AppWindow.immersiveControls.sceneID,
                        value: AppWindow.immersiveControls
                    )
                    await dismissImmersiveSpace()
                    openWindow(
                        id: AppWindow.dashboard.sceneID,
                        value: AppWindow.dashboard
                    )

                case .closed:
                    appModel.immersiveSpaceState = .inTransition

                    switch await openImmersiveSpace(
                        id: appModel.immersiveSpaceID
                    ) {
                    case .opened:
                        // The scene callbacks remain the source of truth for the
                        // final open/closed immersive-space state.
                        dismissWindow(
                            id: AppWindow.dashboard.sceneID,
                            value: AppWindow.dashboard
                        )
                        openWindow(
                            id: AppWindow.immersiveControls.sceneID,
                            value: AppWindow.immersiveControls
                        )

                    case .userCancelled, .error:
                        appModel.immersiveSpaceState = .closed

                    @unknown default:
                        appModel.immersiveSpaceState = .closed
                    }

                case .inTransition:
                    break
                }
            }
        } label: {
            Text(
                appModel.immersiveSpaceState == .open
                    ? "Exit ICU Immersive Space"
                    : "Enter ICU Immersive Space"
            )
            .frame(
                maxWidth: isFullWidth ? .infinity : nil,
                minHeight: isFullWidth ? 60 : nil
            )
        }
        .disabled(
            appModel.immersiveSpaceState == .inTransition
                || isPerformingTransition
        )
        .animation(.none, value: 0)
        .fontWeight(.semibold)
    }
}
