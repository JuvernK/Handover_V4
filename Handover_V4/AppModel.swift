//
//  AppModel.swift
//  Handover_V4
//
//  Created by Juvern Khor on 29/4/2026.
//

import SwiftUI

/// Maintains app-wide state
@MainActor
@Observable
class AppModel {
    let immersiveSpaceID = "ImmersiveSpace"
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    var immersiveSpaceState = ImmersiveSpaceState.closed
    
    let patients = PatientDataLoader.loadOrEmpty()
    
    init() {
        // Temporary debug code to test decoding
        print("Loaded \(patients.count) patients")
        for p in patients {
            print("• \(p.bedNumber): \(p.name) — \(p.initials)")
        }
    }

}
