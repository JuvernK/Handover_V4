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
//    - Track which patient is currently displayed
//    - Track the order of dashboard sections (for drag-and-drop in Step 6)
//    - Provide hooks for SharePlay to update state remotely
//
//  Marked @Observable (Swift 5.9+) so SwiftUI views automatically track
//  changes to its properties without requiring @Published.
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
    
    /// The order in which dashboard sections appear in the grid.
    /// Drag-and-drop in DashboardView mutates this through `moveSection(_:before:)`.
    var sectionOrder: [SectionID] = SectionID.defaultOrder
    
    // MARK: - Init
    
    /// Loads all patients from JSON and selects an initial patient by bed number.
    /// If the bed number is not found, falls back to the first patient.
    init(initialBedNumber: String = "BED-01") {
        loadPatients()
        selectPatient(byBed: initialBedNumber)
    }
    
    // MARK: - Patient management
    
    /// Loads patients from PatientData.json. Called automatically on init.
    func loadPatients() {
        do {
            self.patients = try PatientDataLoader.load()
        } catch {
            print("⚠️ Failed to load patients: \(error)")
            self.patients = []
        }
    }
    
    /// Sets the displayed patient by bed number.
    /// Falls back to the first patient if the bed number isn't found.
    func selectPatient(byBed bedNumber: String) {
        if let match = patients.first(where: { $0.bedNumber == bedNumber }) {
            self.patient = match
        } else {
            self.patient = patients.first
        }
    }
    
    /// Sets the displayed patient by ID. Used internally by tests/previews.
    func selectPatient(byID id: String) {
        if let match = patients.first(where: { $0.id == id }) {
            self.patient = match
        }
    }
    
    // MARK: - Section ordering
    
    /// Moves a section from one index to another within the section order.
    @discardableResult
    func moveSection(from source: Int, to destination: Int) -> Bool {
        guard source >= 0, source < sectionOrder.count else { return false }
        guard destination >= 0, destination <= sectionOrder.count else { return false }
        
        let item = sectionOrder.remove(at: source)
        let insertionIndex = destination > source ? destination - 1 : destination
        sectionOrder.insert(item, at: insertionIndex)
        return true
    }
    
    /// Moves the dragged section so it sits just before the destination section.
    /// Used by .dropDestination handlers in DashboardView.
    ///
    /// Example: dragging Plan onto Vitals → Plan ends up immediately before Vitals.
    /// Dragging a section onto itself is a no-op.
    @discardableResult
    func moveSection(_ dragged: SectionID, before destination: SectionID) -> Bool {
        guard dragged != destination else { return false }
        guard let fromIndex = sectionOrder.firstIndex(of: dragged) else { return false }
        guard sectionOrder.firstIndex(of: destination) != nil else { return false }
        
        // Remove the dragged item first; this may shift the destination index.
        sectionOrder.remove(at: fromIndex)
        
        // Recompute target index after removal.
        let adjustedTarget = sectionOrder.firstIndex(of: destination) ?? sectionOrder.count
        sectionOrder.insert(dragged, at: adjustedTarget)
        return true
    }
    
    /// Resets the section order to the default. Useful for a "reset layout" button.
    func resetSectionOrder() {
        sectionOrder = SectionID.defaultOrder
    }

    /// Applies a remote section order while preserving any sections the sender did
    /// not know about yet.
    func applySectionOrder(_ remoteOrder: [SectionID]) {
        var resolvedOrder: [SectionID] = []

        for section in remoteOrder where !resolvedOrder.contains(section) {
            resolvedOrder.append(section)
        }

        for section in SectionID.defaultOrder where !resolvedOrder.contains(section) {
            resolvedOrder.append(section)
        }

        sectionOrder = resolvedOrder
    }

    func applyDashboardState(_ dashboardState: DashboardState) {
        if let selectedPatientID = dashboardState.selectedPatientID {
            selectPatient(byID: selectedPatientID)
        }

        applySectionOrder(dashboardState.sectionOrder)
    }
}
