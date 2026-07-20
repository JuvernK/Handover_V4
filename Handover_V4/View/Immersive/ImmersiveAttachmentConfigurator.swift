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
            attachment.generateCollisionShapes(recursive: true)
        }
    }

    static func applySyncedPositions(
        _ positions: [String: SIMD3<Float>],
        to attachments: [Entity]
    ) {
        for attachment in attachments {
            guard let runtimeComponent = attachment.components[
                PointOfInterestRuntimeComponent.self
            ], let position = positions[runtimeComponent.cardName] else {
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

            let bounds = attachment.visualBounds(relativeTo: nil)
            guard bounds.extents.x > 0, bounds.extents.y > 0 else {
                continue
            }

            let shape = ShapeResource.generateBox(
                width: bounds.extents.x,
                height: bounds.extents.y,
                depth: ImmersiveConfiguration.collisionDepth
            )
            attachment.components.set(CollisionComponent(shapes: [shape]))
            return
        }
    }
}
