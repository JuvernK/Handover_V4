import Foundation
import Testing
@testable import Handover_V4

@MainActor
struct SpatialCardIdentityTests {
    @Test
    func authoredPointOfInterestNamesResolveToCanonicalCardIdentities() {
        #expect(
            PointOfInterestMapper.destination(for: " Basic-Information ").cardID
                == .basicInformation
        )
        #expect(
            PointOfInterestMapper.destination(for: "Related Background").cardID
                == .section(.relatedBackground)
        )
        #expect(
            PointOfInterestMapper.destination(for: "debug marker").cardID == nil
        )
    }

    @Test
    func canonicalCardIdentityUsesStableWireEncoding() throws {
        let encoded = try JSONEncoder().encode(
            ClinicalCardID.section(.plan)
        )
        #expect(String(decoding: encoded, as: UTF8.self) == "\"plan\"")
        #expect(
            try JSONDecoder().decode(ClinicalCardID.self, from: encoded)
                == .section(.plan)
        )
    }

    @Test
    func sharedCardStateIsKeyedByCanonicalIdentity() {
        let state = SharedCardState()
        let cardID = ClinicalCardID.section(.plan)
        let selection = AbbreviationSelection(
            textID: "plan.item.first.task",
            glossaryEntryID: "af",
            occurrenceIndex: 0
        )

        state.setExpansionState(true, for: cardID)
        state.setPosition(SIMD3<Float>(1, 2, 3), for: cardID)
        state.toggleAbbreviationSelection(selection, for: cardID)

        #expect(state.expansionStates[cardID] == true)
        #expect(state.positions[cardID] == SIMD3<Float>(1, 2, 3))
        #expect(state.abbreviationSelections[cardID] == selection)
    }
}
