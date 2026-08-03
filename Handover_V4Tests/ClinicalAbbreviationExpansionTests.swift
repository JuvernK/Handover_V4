import SwiftUI
import Testing
@testable import Handover_V4

@MainActor
struct ClinicalAbbreviationExpansionTests {
    @Test
    func selectedApprovedAbbreviationExpandsInline() {
        let textID = "plan.item.p5-plan-1.task"
        let text = "Continue CRRT overnight"
        let occurrence = AbbreviationSelection(
            textID: textID,
            glossaryEntryID: "crrt",
            occurrenceIndex: 0
        )

        let rendered = ClinicalAbbreviationGlossary.attributedString(
            for: text,
            textID: textID,
            selection: occurrence,
            baseColor: .primary,
            abbreviationColor: .accentColor
        )

        #expect(
            String(rendered.characters)
                == "Continue CRRT (Continuous renal replacement therapy) overnight"
        )
    }

    @Test
    func repeatedApprovedAbbreviationsHaveStableOccurrenceIdentities() {
        let textID = "plan.item.p5-plan-1.task"

        let occurrences = ClinicalAbbreviationGlossary.occurrences(
            in: "Continue CRRT; hand over CRRT settings",
            textID: textID
        )

        #expect(
            occurrences == [
                AbbreviationSelection(
                    textID: textID,
                    glossaryEntryID: "crrt",
                    occurrenceIndex: 0
                ),
                AbbreviationSelection(
                    textID: textID,
                    glossaryEntryID: "crrt",
                    occurrenceIndex: 1
                )
            ]
        )
    }

    @Test
    func renderedLinksResolveToTheirExactOccurrences() {
        let textID = "plan.item.p5-plan-1.task"
        let rendered = ClinicalAbbreviationGlossary.attributedString(
            for: "Continue CRRT; hand over CRRT settings",
            textID: textID,
            selection: nil,
            baseColor: .primary,
            abbreviationColor: .accentColor
        )

        let selections = rendered.runs.compactMap { run in
            run.link.flatMap(ClinicalAbbreviationGlossary.selection(from:))
        }
        let linkedRuns = rendered.runs.filter { $0.link != nil }

        #expect(
            selections == [
                AbbreviationSelection(
                    textID: textID,
                    glossaryEntryID: "crrt",
                    occurrenceIndex: 0
                ),
                AbbreviationSelection(
                    textID: textID,
                    glossaryEntryID: "crrt",
                    occurrenceIndex: 1
                )
            ]
        )
        #expect(linkedRuns.allSatisfy { $0.underlineStyle != nil })
    }

    @Test
    func selectingSecondRepeatedOccurrenceExpandsOnlyThatOccurrence() {
        let textID = "plan.item.p5-plan-1.task"
        let secondOccurrence = AbbreviationSelection(
            textID: textID,
            glossaryEntryID: "crrt",
            occurrenceIndex: 1
        )

        let rendered = ClinicalAbbreviationGlossary.attributedString(
            for: "Continue CRRT; hand over CRRT settings",
            textID: textID,
            selection: secondOccurrence,
            baseColor: .primary,
            abbreviationColor: .accentColor
        )

        #expect(
            String(rendered.characters)
                == "Continue CRRT; hand over CRRT (Continuous renal replacement therapy) settings"
        )
    }

    @Test
    func excludedVitalLabelsAndUnknownTermsRemainPlain() {
        let textID = "plan.item.p5-plan-1.task"
        let text = "HR and SpO2 stable; continue CRRT with XYZ"

        let occurrences = ClinicalAbbreviationGlossary.occurrences(
            in: text,
            textID: textID
        )
        let rendered = ClinicalAbbreviationGlossary.attributedString(
            for: text,
            textID: textID,
            selection: nil,
            baseColor: .primary,
            abbreviationColor: .accentColor
        )

        #expect(
            occurrences == [
                AbbreviationSelection(
                    textID: textID,
                    glossaryEntryID: "crrt",
                    occurrenceIndex: 0
                )
            ]
        )
        #expect(String(rendered.characters) == text)
    }

    @Test
    func cardSelectionCanBeSelectedReplacedAndToggledOff() {
        let state = SharedCardState()
        let cardName = "plan"
        let first = AbbreviationSelection(
            textID: "plan.item.first.task",
            glossaryEntryID: "af",
            occurrenceIndex: 0
        )
        let second = AbbreviationSelection(
            textID: "plan.item.second.task",
            glossaryEntryID: "crrt",
            occurrenceIndex: 0
        )

        state.toggleAbbreviationSelection(first, for: cardName)
        #expect(state.abbreviationSelections[cardName] == first)

        state.toggleAbbreviationSelection(second, for: cardName)
        #expect(state.abbreviationSelections[cardName] == second)

        state.toggleAbbreviationSelection(second, for: cardName)
        #expect(state.abbreviationSelections[cardName] == nil)
    }
}
