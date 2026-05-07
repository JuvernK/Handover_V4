//
//  AttachmentsProvider.swift
//  Handover_V4
//
//  Created by Juvern Khor on 4/5/2026.
//

/*
Abstract:
A class that maintains references to its attachment views.
*/

import SwiftUI
import Observation

@Observable
final class AttachmentsProvider {

    var attachments: [ObjectIdentifier: AnyView] = [:]

    var sortedTagViewPairs: [(tag: ObjectIdentifier, view: AnyView)] {
        attachments.map { key, value in
            (tag: key, view: value)
        }.sorted { $0.tag < $1.tag }
    }
}


