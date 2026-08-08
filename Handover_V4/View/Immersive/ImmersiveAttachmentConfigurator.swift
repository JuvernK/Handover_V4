//
//  ImmersiveAttachmentConfigurator.swift
//  Handover_V4
//

import RealityKit

enum ImmersiveAttachmentConfigurator {
    static let runtimeQuery = EntityQuery(
        where: .has(PointOfInterestRuntimeComponent.self)
    )

    static func configure(
        _ attachment: Entity,
        anchoredAt pointOfInterest: Entity,
        runtimeComponent: PointOfInterestRuntimeComponent,
        syncedPosition: SIMD3<Float>?
    ) {
        attachment.components.set(BillboardComponent())
        attachment.components.set(InputTargetComponent())
        attachment.components.set(HoverEffectComponent())
        attachment.components.set(runtimeComponent)

        let defaultPosition = pointOfInterest.position(relativeTo: nil)
        attachment.setPosition(syncedPosition ?? defaultPosition, relativeTo: nil)

        Task { @MainActor in
            await createInitialCollisionShape(for: attachment)
        }
    }

    static func regenerateCollisionShapes(for attachments: [Entity]) {
        for attachment in attachments {
            updateCollisionShape(for: attachment)
        }
    }

    static func applySyncedPositions(
        _ positions: [ClinicalCardID: SIMD3<Float>],
        to attachments: [Entity]
    ) {
        for attachment in attachments {
            guard let runtimeComponent = attachment.components[
                PointOfInterestRuntimeComponent.self
            ], let cardID = runtimeComponent.cardID,
               let position = positions[cardID] else {
                continue
            }

            attachment.move(
                to: Transform(
                    scale: attachment.scale,
                    rotation: attachment.orientation,
                    translation: position
                ),
                relativeTo: nil,
                duration: ImmersiveConfiguration.remoteMovementDuration
            )
        }
    }

    private static func createInitialCollisionShape(for attachment: Entity) async {
        for _ in 0..<ImmersiveConfiguration.collisionBoundsAttempts {
            try? await Task.sleep(for: ImmersiveConfiguration.collisionBoundsRetryDelay)

            if updateCollisionShape(for: attachment) {
                return
            }
        }
    }

    @discardableResult
    private static func updateCollisionShape(for attachment: Entity) -> Bool {
        // ViewAttachmentEntity has no mesh, so generateCollisionShapes has no
        // geometry to derive a shape from. Build one from its rendered bounds.
        let bounds = attachment.visualBounds(relativeTo: attachment)
        guard bounds.extents.x > 0, bounds.extents.y > 0 else {
            return false
        }

        let shape = ShapeResource.generateBox(
            width: bounds.extents.x,
            height: bounds.extents.y,
            depth: ImmersiveConfiguration.collisionDepth
        )
        .offsetBy(
            translation: SIMD3<Float>(
                bounds.center.x,
                bounds.center.y,
                bounds.center.z
            )
        )
        attachment.components.set(CollisionComponent(shapes: [shape]))
        return true
    }
}
