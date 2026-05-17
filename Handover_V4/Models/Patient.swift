//
//  Patient.swift
//  Handover_V3
//
//  Data model for an ICU patient handover.
//
//  Design notes:
//  - All structs are Identifiable + Codable so they work directly with SwiftUI ForEach
//    and can be loaded from PatientData.json.
//  - IDs are plain Strings (e.g. "p1", "p1-vital-1") for readability while prototyping.
//  - The previous ISBARHandover struct has been removed — ISBAR is a communication
//    framework, not a data structure. The nurse mentally constructs ISBAR sentences
//    from the structured fields below.
//  - Length of stay is computed at runtime from icuAdmissionDate, so the LOS
//    automatically updates each day without editing the JSON.
//

import Foundation

// MARK: - Patient

struct Patient: Identifiable, Codable, Hashable {
    let id: String
    let bedNumber: String
    let mrn: String
    let name: String
    let age: Int
    let gender: Gender
    let acuity: AcuityLevel
    let trajectory: Trajectory
    
    let codeStatus: CodeStatus
    let allergies: [Allergy]
    
    /// Short clinical label — what the patient is in for.
    /// e.g. "Post-CABG x3", "Severe ARDS — Influenza A".
    /// Shown prominently in the patient header.
    let diagnosis: String
    let relatedBackground: RelatedBackground
    
    /// Optional name of an image asset in the app bundle to use as the
    /// patient's avatar. If nil or missing, the UI falls back to initials.
    let avatarImageName: String?
    
    /// When the patient was admitted to ICU. Used to compute length of stay.
    let icuAdmissionDate: Date
    
    let vitals: [VitalSign]
    let infusions: [Infusion]
    let lines: [LineAccess]
    let labs: [LabResult]
    let systems: [SystemAssessment]
    let plan: [PlanItem]
    let family: FamilyInfo
    let escalation: EscalationInfo

    init(
        id: String,
        bedNumber: String,
        mrn: String,
        name: String,
        age: Int,
        gender: Gender,
        acuity: AcuityLevel,
        trajectory: Trajectory = .stable,
        codeStatus: CodeStatus,
        allergies: [Allergy],
        diagnosis: String,
        relatedBackground: RelatedBackground = .empty,
        avatarImageName: String?,
        icuAdmissionDate: Date,
        vitals: [VitalSign],
        infusions: [Infusion],
        lines: [LineAccess],
        labs: [LabResult],
        systems: [SystemAssessment],
        plan: [PlanItem],
        family: FamilyInfo,
        escalation: EscalationInfo
    ) {
        self.id = id
        self.bedNumber = bedNumber
        self.mrn = mrn
        self.name = name
        self.age = age
        self.gender = gender
        self.acuity = acuity
        self.trajectory = trajectory
        self.codeStatus = codeStatus
        self.allergies = allergies
        self.diagnosis = diagnosis
        self.relatedBackground = relatedBackground
        self.avatarImageName = avatarImageName
        self.icuAdmissionDate = icuAdmissionDate
        self.vitals = vitals
        self.infusions = infusions
        self.lines = lines
        self.labs = labs
        self.systems = systems
        self.plan = plan
        self.family = family
        self.escalation = escalation
    }
    
    // MARK: - Computed properties
    
    /// Computed initials from name (e.g. "Ahmad bin Razali" → "AR").
    /// Used for the avatar circle when no image is provided.
    var initials: String {
        let words = name.split(separator: " ").map(String.init)
        guard !words.isEmpty else { return "?" }
        if words.count == 1 {
            return String(words[0].prefix(2)).uppercased()
        }
        let first = words.first?.first.map(String.init) ?? ""
        let last = words.last?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }
    
    /// Number of full days the patient has been in ICU.
    /// Returns 0 if admitted today.
    var lengthOfStay: Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: icuAdmissionDate)
        let now = cal.startOfDay(for: Date())
        return cal.dateComponents([.day], from: start, to: now).day ?? 0
    }
    
    /// Human-readable LOS for display (e.g. "ICU Day 5").
    var lengthOfStayDisplay: String {
        "ICU Day \(lengthOfStay)"
    }
}

// MARK: - Allergy

struct Allergy: Codable, Hashable {
    let substance: String
    let reaction: String
}

// MARK: - Related Background

struct RelatedBackground: Codable, Hashable {
    let pastMedicalHistory: [String]
    let presentingComplaint: String
    let socialHistory: [String]
    let relevantContext: [String]

    static let empty = RelatedBackground(
        pastMedicalHistory: [],
        presentingComplaint: "",
        socialHistory: [],
        relevantContext: []
    )
}

// MARK: - Vital Sign

struct VitalSign: Identifiable, Codable, Hashable {
    let id: String
    let label: String           // "HR", "SpO₂"
    let value: String           // "88" (current value as displayed)
    let unit: String            // "bpm"
    let status: VitalStatus
    let timestamp: Date
    
    /// 12-point history covering the past 12 hours (1 point per hour).
    /// The last value in the array represents the most recent reading.
    let history: [Double]
    
    /// Direction the vital is moving in (compared to earlier in the window).
    let trend: Trend
    
    // MARK: - Computed helpers
    
    var historyMin: Double? { history.min() }
    var historyMax: Double? { history.max() }
    
    /// Formatted "low – high" string (e.g. "76 – 102") suitable for display.
    var rangeDisplay: String {
        guard let lo = historyMin, let hi = historyMax else { return "" }
        return "\(formatNumber(lo)) – \(formatNumber(hi))"
    }
    
    private func formatNumber(_ n: Double) -> String {
        if n.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(n))
        }
        return String(format: "%.1f", n)
    }
}

// MARK: - Infusion

struct Infusion: Identifiable, Codable, Hashable {
    let id: String
    let drugName: String
    let dose: String
    let route: String
    let purpose: String
    let isHighAlert: Bool
}

// MARK: - Line / Access

struct LineAccess: Identifiable, Codable, Hashable {
    let id: String
    let type: String
    let location: String
}

// MARK: - Lab Result

struct LabResult: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let value: String
    let unit: String
    let status: VitalStatus
    let trend: Trend?
}

// MARK: - System Assessment

struct SystemAssessment: Identifiable, Codable, Hashable {
    let id: String
    let system: BodySystem
    let summary: String
    let concerns: [String]
}

// MARK: - Plan Item

struct PlanItem: Identifiable, Codable, Hashable {
    let id: String
    let task: String
    let dueTime: Date?
    let priority: Priority
}

// MARK: - Family Info

struct FamilyInfo: Codable, Hashable {
    let primaryContact: String
    let presentAtBedside: Bool
    let notes: String
}

// MARK: - Escalation Info

struct EscalationInfo: Codable, Hashable {
    let mainConcerns: [String]
    let triggers: [String]
    let escalateTo: String
}
