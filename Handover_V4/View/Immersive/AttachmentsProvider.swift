//
//  AttachmentsProvider.swift
//  Handover_V4
//

import SwiftUI
import Observation

/// Stores the SwiftUI views exposed as RealityKit attachments.
@Observable
final class AttachmentsProvider {
    var attachments: [ObjectIdentifier: AnyView] = [:]

    var sortedTagViewPairs: [(tag: ObjectIdentifier, view: AnyView)] {
        attachments
            .map { (tag: $0.key, view: $0.value) }
            .sorted { $0.tag < $1.tag }
    }
}
