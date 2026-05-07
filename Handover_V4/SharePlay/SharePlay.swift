//
//  SharePlayLogic.swift
//  Handover_V4
//
//  Created by Juvern Khor on 18/3/2026.
//

import Foundation
import GroupActivities
import CoreTransferable
import UIKit

/// Defines the SharePlay group activity for collaborative cube color changes.
struct SharePlayTogether: GroupActivity, Transferable {
    /// Configures the displayed SharePlay activity metadata.
    var metadata: GroupActivityMetadata = {
        var metadata = GroupActivityMetadata()
        metadata.type = .generic
        metadata.title = "ICU Nurse Handover Session with VisionOS"
        return metadata
    }()
}

