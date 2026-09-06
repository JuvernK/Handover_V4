//
//  RelatedBackgroundCard.swift
//  Handover_V4
//
//  Dashboard card showing clinically relevant background information.
//
//  This combines:
//    - Presenting complaint
//    - Past medical history
//    - Social history
//

import SwiftUI

struct RelatedBackgroundCard: View {
    let patient: Patient

    private var background: RelatedBackground {
        patient.relatedBackground
    }

    private var isEmpty: Bool {
        background.presentingComplaint.isEmpty &&
        background.pastMedicalHistory.isEmpty &&
        background.socialHistory.isEmpty &&
        background.relevantContext.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardHeader(title: "Related Background", systemImage: "person.text.rectangle")

            Divider().padding(.horizontal, 12)

            if isEmpty {
                EmptyState()
                    .padding(16)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    if !background.presentingComplaint.isEmpty {
                        BackgroundSection(
                            title: "Presenting complaint",
                            systemImage: "doc.text.magnifyingglass"
                        ) {
                            Text(background.presentingComplaint)
                                .font(.system(size: 13))
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if !background.pastMedicalHistory.isEmpty {
                        BackgroundSection(
                            title: "Past medical history",
                            systemImage: "cross.case.fill"
                        ) {
                            BulletList(items: background.pastMedicalHistory)
                        }
                    }

                    if !background.socialHistory.isEmpty {
                        BackgroundSection(
                            title: "Social history",
                            systemImage: "house.and.flag.fill"
                        ) {
                            BulletList(items: background.socialHistory)
                        }
                    }

                    if !background.relevantContext.isEmpty {
                        BackgroundSection(
                            title: "Relevant context",
                            systemImage: "info.circle.fill"
                        ) {
                            BulletList(items: background.relevantContext)
                        }
                    }
                }
                .padding(16)
            }
        }
        .glassBackgroundEffect(in: .rect(cornerRadius: 16))
    }
}

// MARK: - Background section

private struct BackgroundSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 14)

                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
            }

            content
        }
    }
}

private struct BulletList: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(.secondary.opacity(0.5))
                        .frame(width: 5, height: 5)
                        .padding(.top, 6)

                    Text(item)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Empty state

private struct EmptyState: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.text.rectangle")
                .foregroundStyle(.secondary)
            Text("No related background recorded")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

// MARK: - Previews

#if DEBUG
extension Patient {
    static var mockRelatedBackground_Ahmad: Patient {
        let p = mockHeader_Ahmad
        return Patient(
            id: p.id, bedNumber: p.bedNumber, mrn: p.mrn, name: p.name,
            age: p.age, gender: p.gender, acuity: p.acuity,
            codeStatus: p.codeStatus, allergies: p.allergies,
            diagnosis: p.diagnosis,
            relatedBackground: RelatedBackground(
                pastMedicalHistory: [
                    "Triple-vessel coronary artery disease",
                    "Hypertension",
                    "Type 2 diabetes mellitus",
                    "Hyperlipidaemia"
                ],
                presentingComplaint: "Elective ICU admission after coronary artery bypass grafting x3 for progressive exertional angina and positive stress testing.",
                socialHistory: [
                    "Ex-smoker with approximately 30 pack-year history; stopped 5 years ago",
                    "Lives with spouse and was independent with activities of daily living pre-operatively"
                ],
                relevantContext: []
            ),
            avatarImageName: p.avatarImageName,
            icuAdmissionDate: p.icuAdmissionDate,
            vitals: [], infusions: [], lines: [], labs: [], systems: [], plan: [],
            family: p.family,
            escalation: p.escalation
        )
    }
}
#endif

#Preview("Related Background — Ahmad") {
    RelatedBackgroundCard(patient: .mockRelatedBackground_Ahmad)
        .frame(width: 420)
        .padding()
}
