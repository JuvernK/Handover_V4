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

    private let cardID = ClinicalCardID.section(.relatedBackground)

    private var background: RelatedBackground {
        patient.relatedBackground
    }

    private var isEmpty: Bool {
        background.presentingComplaint.isEmpty &&
        background.pastMedicalHistory.isEmpty &&
        background.socialHistory.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardHeader(title: "Related Background", systemImage: "person.text.rectangle")

            Divider().padding(.horizontal, 12)

            if isEmpty {
                CardEmptyState(
                    systemImage: "person.text.rectangle",
                    message: "No related background recorded"
                )
                    .padding(16)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    if !background.presentingComplaint.isEmpty {
                        BackgroundSection(
                            title: "Presenting complaint",
                            systemImage: "doc.text.magnifyingglass"
                        ) {
                            CardClinicalAbbreviationText(
                                background.presentingComplaint,
                                textID: .field(
                                    "presenting_complaint",
                                    in: cardID
                                ),
                                font: .system(size: 13),
                                foregroundColor: .primary
                            )
                        }
                    }

                    if !background.pastMedicalHistory.isEmpty {
                        BackgroundSection(
                            title: "Past medical history",
                            systemImage: "cross.case.fill"
                        ) {
                            BulletList(
                                items: background.pastMedicalHistory,
                                fieldName: "past_medical_history",
                                cardID: cardID
                            )
                        }
                    }

                    if !background.socialHistory.isEmpty {
                        BackgroundSection(
                            title: "Social history",
                            systemImage: "house.and.flag.fill"
                        ) {
                            BulletList(
                                items: background.socialHistory,
                                fieldName: "social_history",
                                cardID: cardID
                            )
                        }
                    }
                }
                .padding(16)
            }
        }
        .cardContainerBackground()
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
    let fieldName: String
    let cardID: ClinicalCardID

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(.secondary.opacity(0.5))
                        .frame(width: 5, height: 5)
                        .padding(.top, 6)

                    CardClinicalAbbreviationText(
                        item,
                        textID: .sourceItemField(
                            fieldName,
                            sourceIndex: index,
                            in: cardID
                        ),
                        font: .system(size: 13),
                        foregroundColor: .primary
                    )
                }
            }
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
        .environment(AppModel())
        .frame(width: 420)
        .padding()
}
