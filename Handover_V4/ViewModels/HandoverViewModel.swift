// Flow: PatientData.json -> PatientDataLoader -> HandoverViewModel.patient -> DashboardView + ImmersiveView.
//
//  HandoverViewModel.swift
//  Handover_V4
//
//  Created by Juvern Khor on 30/4/2026.
//
//  Source of truth for what the dashboard is showing.
//
//  Responsibilities:
//    - Load patients from PatientData.json
//    - Track which patient is currently displayed via appmodel.patient
//

import Foundation
import Observation

@Observable
@MainActor
final class HandoverViewModel {

    /// All patients loaded from the bundle.
    private(set) var patients: [Patient] = []

    /// The patient currently displayed on the dashboard.
    var patient: Patient?

    /// Loads all patients from JSON and selects an initial patient by bed number.
    /// If the bed number is not found, falls back to the first patient.
    init(initialBedNumber: String = "BED-01") {
        loadPatients()
        selectPatient(byBed: initialBedNumber)
    }

    // MARK: - Patient management

    /// Loads patients from PatientData.json.
    func loadPatients() {
        do {
            self.patients = try PatientDataLoader.load()
        } catch {
            print("⚠️ Failed to load patients: \(error)")
            self.patients = []
        }
    }

    /// Sets the displayed patient by selected bed number.
    /// Falls back to the first patient if the bed number isn't found.
    func selectPatient(byBed bedNumber: String) {
        if let match = patients.first(where: { $0.bedNumber == bedNumber }) {
            self.patient = match
        } else {
            self.patient = patients.first
        }
    }
}
