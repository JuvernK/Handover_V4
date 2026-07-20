//
//  ImmersiveView.swift
//  Handover_V4
//
//  Coordinates the RealityKit scene, spatial attachments, and shared state.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(HandoverViewModel.self) private var handoverViewModel

    @State private var attachmentsProvider = AttachmentsProvider()
    @State private var subscriptions: [EventSubscription] = []
    @State private var attachmentEntities: [Entity] = []

    var body: some View {
        RealityView { content, _ in
            do {
                let scene = try await ImmersiveSceneLoader.load()
                content.add(scene)

                let subscription = content.subscribe(
                    to: ComponentEvents.DidAdd.self,
                    componentType: PointOfInterestComponent.self
                ) { event in
                    ImmersiveAttachmentFactory.createAttachment(
                        for: event.entity,
                        patient: handoverViewModel.patient,
                        provider: attachmentsProvider
                    )
                }
                subscriptions.append(subscription)
            } catch {
                print("Failed to load the immersive scene: \(error.localizedDescription)")
            }
        } update: { content, attachments in
            guard let scene = content.entities.first?.scene else { return }

            for pointOfInterest in scene.performQuery(ImmersiveAttachmentConfigurator.runtimeQuery) {
                guard let runtimeComponent = pointOfInterest.components[
                    PointOfInterestRuntimeComponent.self
                ] else {
                    continue
                }

                guard let attachment = attachments.entity(
                    for: runtimeComponent.attachmentTag
                ), attachment.parent == nil else {
                    continue
                }

                // Attach to the root to avoid inheriting the ICU scene's scale.
                content.add(attachment)
                ImmersiveAttachmentConfigurator.configure(
                    attachment,
                    anchoredAt: pointOfInterest,
                    runtimeComponent: runtimeComponent,
                    syncedPosition: appModel.cardPositions[runtimeComponent.cardName]
                )

                if !attachmentEntities.contains(attachment) {
                    attachmentEntities.append(attachment)
                }
            }
        } attachments: {
            ForEach(attachmentsProvider.sortedTagViewPairs, id: \.tag) { pair in
                Attachment(id: pair.tag) {
                    pair.view
                }
            }
        }
        .spatialCardGestures()
        .onChange(of: appModel.cardStates) { _, _ in
            Task { @MainActor in
                try? await Task.sleep(for: ImmersiveConfiguration.collisionResizeDelay)
                ImmersiveAttachmentConfigurator.regenerateCollisionShapes(
                    for: attachmentEntities
                )
            }
        }
        .onChange(of: appModel.cardPositions) { _, newPositions in
            ImmersiveAttachmentConfigurator.applySyncedPositions(
                newPositions,
                to: attachmentEntities
            )
        }
    }
}

#Preview(immersionStyle: .full) {
    let appModel = AppModel()
    ImmersiveView()
        .environment(appModel)
        .environment(appModel.handoverViewModel)
}
