// Flow: Patient records -> PatientHeaderView -> DashboardTheme + SwiftUI presentation.
//
//  PatientHeaderView.swift
//  Handover_V4
//
//  Created by Juvern Khor on 29/4/2026.
//
//
//  Pinned header shown at the top of the dashboard. Not draggable.
//
//
//  Avatar prefers an asset image (Patient.avatarImageName) when available,
//  otherwise falls back to initials in a coloured circle.
//

import SwiftUI

struct PatientHeaderView: View {
    let patient: Patient

    @Environment(\.isDashboardSurface) private var isDashboardSurface

    var body: some View {
        ViewThatFits(in: .horizontal) {
            if isDashboardSurface {
                HStack(alignment: .top, spacing: 24) {
                    identity.frame(minWidth: 420)
                    VStack(alignment: .trailing, spacing: 12) {
                        statusBadges
                        AllergiesRow(allergies: patient.allergies)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
            }
            VStack(alignment: .leading, spacing: 14) {
                identity
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        statusBadges
                        AllergiesRow(allergies: patient.allergies)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        statusBadges
                        AllergiesRow(allergies: patient.allergies)
                    }
                }
            }
        }
        .padding(24)
    }

    /// Safety information moves beside identity only when both can fit without clipping.
    private var identity: some View {
        HStack(alignment: .top, spacing: 16) {
            AvatarView(patient: patient)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 7) {
                Text(patient.name)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(DashboardTheme.foreground)
                    .accessibilityAddTraits(.isHeader)
                Text(patient.diagnosis)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DashboardTheme.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(demographicsLine)  ·  \(patient.lengthOfStayDisplay)")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(DashboardTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var statusBadges: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                AcuityBadge(acuity: patient.acuity)
                TrajectoryBadge(trajectory: patient.trajectory)
                CodeStatusBadge(codeStatus: patient.codeStatus)
            }
            VStack(alignment: .leading, spacing: 8) {
                AcuityBadge(acuity: patient.acuity)
                TrajectoryBadge(trajectory: patient.trajectory)
                CodeStatusBadge(codeStatus: patient.codeStatus)
            }
        }
    }

    /// "62M  ·  BED-01  ·  MRN-202400341"
    private var demographicsLine: String {
        let genderLetter = patient.gender == .male ? "M" : "F"
        return "\(patient.age)\(genderLetter)  ·  \(patient.bedNumber)  ·  \(patient.mrn)"
    }
}

// MARK: - Avatar

private struct AvatarView: View {
    let patient: Patient

    private let size: CGFloat = 72

    var body: some View {
        if let imageName = patient.avatarImageName,
           UIImage(named: imageName) != nil {
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            // Fallback: initials in a coloured circle
            ZStack {
                Circle()
                    .fill(DashboardTheme.glassRaised)
                Text(patient.initials)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(DashboardTheme.secondary)
            }
            .frame(width: size, height: size)
        }
    }
}

// MARK: - Acuity badge

private struct AcuityBadge: View {
    let acuity: AcuityLevel

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: acuity.iconName)
                .font(.system(size: 11, weight: .semibold))
            Text(acuity.displayText)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(acuity.statusColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(acuity.statusColor.opacity(0.16))
        .overlay(Capsule().strokeBorder(acuity.statusColor.opacity(0.65), lineWidth: 1))
        .clipShape(Capsule())
    }
}

private extension AcuityLevel {
    var displayText: String {
        switch self {
        case .stable: return "Stable acuity"
        case .critical: return "Critical acuity"
        }
    }

    var iconName: String {
        switch self {
        case .stable: return "checkmark.shield.fill"
        case .critical: return "exclamationmark.triangle.fill"
        }
    }

    var statusColor: Color {
        switch self {
        case .stable: return DashboardTheme.normal
        case .critical: return DashboardTheme.critical
        }
    }
}

// MARK: - Trajectory badge

private struct TrajectoryBadge: View {
    let trajectory: Trajectory

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: trajectory.iconName)
                .font(.system(size: 11, weight: .semibold))
            Text(trajectory.displayText)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(trajectory.statusColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(trajectory.statusColor.opacity(0.16))
        .overlay(Capsule().strokeBorder(trajectory.statusColor.opacity(0.65), lineWidth: 1))
        .clipShape(Capsule())
    }
}

private extension Trajectory {
    var displayText: String {
        switch self {
        case .improving: return "Improving"
        case .stable: return "Stable"
        case .worsening: return "Worsening"
        }
    }

    var iconName: String {
        switch self {
        case .improving: return "arrow.down.right.circle.fill"
        case .stable: return "equal.circle.fill"
        case .worsening: return "arrow.up.right.circle.fill"
        }
    }

    var statusColor: Color {
        switch self {
        case .improving: return DashboardTheme.normal
        case .stable: return DashboardTheme.secondary
        case .worsening: return DashboardTheme.warning
        }
    }
}

// MARK: - Allergies

private struct AllergiesRow: View {
    let allergies: [Allergy]

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(allergies.isEmpty ? DashboardTheme.secondary : DashboardTheme.critical)

            if allergies.isEmpty {
                Text("NKDA")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DashboardTheme.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(DashboardTheme.glassRaised)
                    .clipShape(Capsule())
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(allergies, id: \.substance) { allergy in
                        AllergyPill(allergy: allergy)
                    }
                }
            }
        }
    }
}

private struct AllergyPill: View {
    let allergy: Allergy

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(allergy.substance)
                .font(.system(size: 13, weight: .semibold))
            Text(allergy.reaction)
                .font(.system(size: 12))
                .foregroundStyle(DashboardTheme.foreground)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(DashboardTheme.foreground)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(DashboardTheme.critical.opacity(0.16))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(DashboardTheme.critical, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Code status badge

private struct CodeStatusBadge: View {
    let codeStatus: CodeStatus

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 12, weight: .semibold))
            Text(codeStatus.displayText)
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(backgroundColor)
        .clipShape(Capsule())
    }

    private var iconName: String {
        switch codeStatus {
        case .fullCode: return "checkmark.circle.fill"
        case .dnr:      return "hand.raised.fill"
        case .custom:   return "exclamationmark.circle.fill"
        }
    }

    private var foregroundColor: Color {
        switch codeStatus {
        case .fullCode: return DashboardTheme.secondary
        case .dnr:      return DashboardTheme.warning
        case .custom:   return DashboardTheme.warning
        }
    }

    private var backgroundColor: Color {
        switch codeStatus {
        case .fullCode: return DashboardTheme.secondary.opacity(0.15)
        case .dnr:      return DashboardTheme.warning.opacity(0.15)
        case .custom:   return DashboardTheme.warning.opacity(0.18)
        }
    }
}

// MARK: - Previews

#if DEBUG
extension Patient {
    static var mockHeader_Ahmad: Patient {
        Patient(
            id: "p1",
            bedNumber: "BED-01",
            mrn: "MRN-202400341",
            name: "Ahmad bin Razali",
            age: 62,
            gender: .male,
            acuity: .stable,
            codeStatus: .fullCode,
            allergies: [Allergy(substance: "Penicillin", reaction: "Rash")],
            diagnosis: "Post-CABG x3",
            avatarImageName: nil,
            icuAdmissionDate: Date().addingTimeInterval(-86400),  // 1 day ago
            vitals: [], infusions: [], lines: [], labs: [], systems: [], plan: [],
            family: FamilyInfo(primaryContact: "Wife", presentAtBedside: true, notes: ""),
            escalation: EscalationInfo(mainConcerns: [], triggers: [], escalateTo: "ICU Reg")
        )
    }

    static var mockHeader_Siti: Patient {
        Patient(
            id: "p2",
            bedNumber: "BED-02",
            mrn: "MRN-202401187",
            name: "Siti Norzahra bt Hamdan",
            age: 47,
            gender: .female,
            acuity: .critical,
            codeStatus: .fullCode,
            allergies: [
                Allergy(substance: "Sulphonamides", reaction: "Anaphylaxis"),
                Allergy(substance: "NSAIDs", reaction: "GI bleed")
            ],
            diagnosis: "Septic shock — RLL pneumonia",
            avatarImageName: nil,
            icuAdmissionDate: Date().addingTimeInterval(-86400 * 4),
            vitals: [], infusions: [], lines: [], labs: [], systems: [], plan: [],
            family: FamilyInfo(primaryContact: "Husband", presentAtBedside: true, notes: ""),
            escalation: EscalationInfo(mainConcerns: [], triggers: [], escalateTo: "ICU Reg")
        )
    }

    static var mockHeader_Mariam: Patient {
        Patient(
            id: "p6",
            bedNumber: "BED-06",
            mrn: "MRN-202400123",
            name: "Datin Mariam bt Osman",
            age: 71,
            gender: .female,
            acuity: .stable,
            codeStatus: .custom("Full Code (Advance Directive: no CPR if primary graft non-function)"),
            allergies: [
                Allergy(substance: "Vancomycin", reaction: "Red Man Syndrome"),
                Allergy(substance: "Latex", reaction: "Contact reaction")
            ],
            diagnosis: "Orthotopic liver transplant",
            avatarImageName: nil,
            icuAdmissionDate: Date().addingTimeInterval(-86400 * 3),
            vitals: [], infusions: [], lines: [], labs: [], systems: [], plan: [],
            family: FamilyInfo(primaryContact: "Husband", presentAtBedside: false, notes: ""),
            escalation: EscalationInfo(mainConcerns: [], triggers: [], escalateTo: "Transplant Surgeon")
        )
    }

    static var mockHeader_NoAllergies: Patient {
        let p = mockHeader_Ahmad
        return Patient(
            id: p.id,
            bedNumber: p.bedNumber,
            mrn: p.mrn,
            name: "Lim Wei Jian",
            age: 29,
            gender: .male,
            acuity: .critical,
            codeStatus: .fullCode,
            allergies: [],   // NKDA
            diagnosis: "Severe DKA + AKI Stage 3",
            avatarImageName: nil,
            icuAdmissionDate: Date(),  // admitted today → "Admission day"
            vitals: [], infusions: [], lines: [], labs: [], systems: [], plan: [],
            family: FamilyInfo(primaryContact: "Parents", presentAtBedside: false, notes: ""),
            escalation: EscalationInfo(mainConcerns: [], triggers: [], escalateTo: "ICU Reg")
        )
    }
}
#endif

#Preview("patient header") {
    let patients = PatientDataLoader.loadOrEmpty()

    return Group {
        if let p = patients.first(where: { $0.bedNumber == "BED-02" }) {
            VStack(spacing: 16) {
                LinesAccessCard(patient: p)
                LabsCard(patient: p)
                InfusionsCard(patient: p)
            }
            .padding()
                } else {
            Text("No patients loaded")
        }
    }
}
