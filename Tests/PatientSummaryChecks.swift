// Flow: bundled JSON -> Patient decoding -> summary compatibility checks.
import Foundation

/// Checks the schema migration against every bundled case and older/partial records.
@main
struct PatientSummaryChecks {
    static func main() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: "Handover_V4/Data/PatientData.json"))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let patients = try decoder.decode(PatientDataFile.self, from: data).patients
        precondition(patients.count == 5)
        for patient in patients {
            guard let summaries = patient.handoverSummaries else { preconditionFailure("Missing case summaries") }
            for summary in [summaries.situation, summaries.background, summaries.assessment, summaries.recommendation] {
                precondition(!(summary?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true))
            }
        }
        let root = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        var record = (root["patients"] as! [[String: Any]])[0]
        record.removeValue(forKey: "handoverSummaries")
        let oldPatient = try decoder.decode(Patient.self, from: JSONSerialization.data(withJSONObject: record))
        precondition(oldPatient.handoverSummaries == nil)
        record["handoverSummaries"] = ["assessment": "Authored assessment only."]
        let partial = try decoder.decode(Patient.self, from: JSONSerialization.data(withJSONObject: record))
        precondition(partial.handoverSummaries?.assessment == "Authored assessment only.")
        precondition(partial.handoverSummaries?.situation == nil)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let roundTrip = try decoder.decode(Patient.self, from: encoder.encode(patients[1]))
        precondition(roundTrip == patients[1])
        print("Patient summary checks passed")
    }
}
