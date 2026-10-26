// Flow: LauncherView Start button + Share menu -> SharePlayTogether -> AppModel.observeGroupSessions.
//
//  SharePlay.swift
//  Handover_V4
//
//  Created by Juvern Khor on 18/3/2026.
//

import Foundation
import GroupActivities
import CoreTransferable

/// The shared ICU handover. `Transferable` lets the system Share menu offer it, including
/// nearby sharing between Vision Pro wearers in the same room.
struct SharePlayTogether: GroupActivity, Transferable {
    var metadata: GroupActivityMetadata = {
        var metadata = GroupActivityMetadata()
        metadata.type = .generic
        metadata.title = "ICU Handover"
        metadata.subtitle = "Present the patient handover together."
        return metadata
    }()
}
