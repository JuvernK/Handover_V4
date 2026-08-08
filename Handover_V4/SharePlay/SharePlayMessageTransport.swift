//
//  SharePlayMessageTransport.swift
//  Handover_V4
//

import Foundation

/// The message boundary used by SharePlayCoordinator.
///
/// Keeping GroupSessionMessenger behind this interface lets synchronization
/// behavior be exercised with an in-memory two-participant transport.
@MainActor
protocol SharePlayMessageTransport: ReplicationTransport {
    func endSession()
}
