//
//  PointOfInterestRuntimeComponent.swift
//  Handover_V4
//
//  Created by Juvern Khor on 4/5/2026.
//

import Foundation
import RealityKit

struct PointOfInterestRuntimeComponent: Component {
    let attachmentTag: ObjectIdentifier
    let cardID: ClinicalCardID?
    let unknownPOIName: String?

    var diagnosticName: String {
        cardID?.canonicalName ?? unknownPOIName ?? "unknown"
    }
}
