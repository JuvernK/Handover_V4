//
//  PatientDataLoader.swift
//  Handover_V4
//
//  Created by Juvern Khor on 29/4/2026.
//
//  Loads PatientData.json from a bundle and decodes it into patients.
//

import Foundation

protocol PatientLoading {
    func loadPatients() throws -> [Patient]
}

struct PatientDataLoader: PatientLoading {
    private let bundle: Bundle
    private let resourceName: String

    init(bundle: Bundle = .main, resourceName: String = "PatientData") {
        self.bundle = bundle
        self.resourceName = resourceName
    }

    func loadPatients() throws -> [Patient] {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw PatientDataLoadingError.fileNotFound(resourceName: resourceName)
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw PatientDataLoadingError.unreadableFile(underlying: error)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(PatientDataFile.self, from: data).patients
        } catch {
            throw PatientDataLoadingError.invalidFile(underlying: error)
        }
    }
}

enum PatientDataLoadingError: LocalizedError {
    case fileNotFound(resourceName: String)
    case unreadableFile(underlying: Error)
    case invalidFile(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let resourceName):
            return "\(resourceName).json could not be found."
        case .unreadableFile:
            return "Patient data could not be read."
        case .invalidFile:
            return "Patient data is not in the expected format."
        }
    }

    var failureReason: String? {
        switch self {
        case .fileNotFound:
            return nil
        case .unreadableFile(let underlying), .invalidFile(let underlying):
            return underlying.localizedDescription
        }
    }
}

private struct PatientDataFile: Decodable {
    let patients: [Patient]
}
