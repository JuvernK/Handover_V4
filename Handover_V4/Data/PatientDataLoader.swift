//
//  PatientDataLoader.swift
//  Handover_V4
//
//  Created by Juvern Khor on 29/4/2026.
//
//  Loads PatientData.json from the app bundle and decodes into [Patient].
//

import Foundation

// MARK: - Top-level container matching the JSON root

struct PatientDataFile: Codable {
    let patients: [Patient]
}

// MARK: - Loader

enum PatientDataLoader {
    
    /// Loads and decodes PatientData.json from the main bundle.
    /// - Returns: An array of Patient objects.
    /// - Throws: An error if the file is missing or decoding fails.
    static func load() throws -> [Patient] {
        guard let url = Bundle.main.url(forResource: "PatientData", withExtension: "json") else {
            throw LoaderError.fileNotFound
        }
        
        let data = try Data(contentsOf: url)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601   // matches "2026-04-28T07:00:00Z"
        
        let file = try decoder.decode(PatientDataFile.self, from: data)
        return file.patients
    }
    
    /// Convenience non-throwing variant — returns [] if anything goes wrong.
    /// Useful for SwiftUI previews and quick prototyping.
    static func loadOrEmpty() -> [Patient] {
        (try? load()) ?? []
    }
    
    enum LoaderError: Error {
        case fileNotFound
    }
}

// MARK: - Example usage in a ViewModel
//
// @Observable
// final class HandoverViewModel {
//     var patients: [Patient] = []
//     var currentPatient: Patient?
//
//     init() {
//         do {
//             self.patients = try PatientDataLoader.load()
//             self.currentPatient = patients.first
//         } catch {
//             print("Failed to load patient data: \(error)")
//         }
//     }
// }
