//
//  ImmersiveAttachmentFactory.swift
//  Handover_V4
//

import SwiftUI
import RealityKit
import RealityKitContent

enum ImmersiveAttachmentFactory {
    static func createAttachment(
        for entity: Entity,
        patient: Patient?,
        provider: AttachmentsProvider
    ) {
        guard entity.components[PointOfInterestRuntimeComponent.self] == nil else {
            return
        }
        guard let pointOfInterest = entity.components[PointOfInterestComponent.self] else {
            return
        }
        guard let patient else {
            print("POI '\(pointOfInterest.name)' has no patient to display.")
            return
        }

        let tag: ObjectIdentifier = entity.id
        let view = AnyView(
            SpatialCardView(poiName: pointOfInterest.name, patient: patient)
                .tag(tag)
        )

        entity.components[PointOfInterestRuntimeComponent.self] =
            PointOfInterestRuntimeComponent(
                attachmentTag: tag,
                cardName: pointOfInterest.name
            )
        provider.attachments[tag] = view
    }
}
