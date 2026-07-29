//
//  ClinicalAbbreviationText.swift
//  Handover_V4
//
//  Tap-enabled glossary text for clinical abbreviations.
//

import Foundation
import SwiftUI

/// Card-aware inline presentation used by every production clinical field.
struct CardClinicalAbbreviationText: View {
    @Environment(AppModel.self) private var appModel

    let text: String
    let textID: ClinicalTextID
    let font: Font
    let foregroundColor: Color
    let abbreviationColor: Color
    let fixedVertical: Bool

    init(
        _ text: String,
        textID: ClinicalTextID,
        font: Font = .body,
        foregroundColor: Color = .primary,
        abbreviationColor: Color = .accentColor,
        fixedVertical: Bool = true
    ) {
        self.text = text
        self.textID = textID
        self.font = font
        self.foregroundColor = foregroundColor
        self.abbreviationColor = abbreviationColor
        self.fixedVertical = fixedVertical
    }

    var body: some View {
        ClinicalAbbreviationText(
            text,
            textID: textID.rawValue,
            selection: appModel.abbreviationSelection(for: textID.cardID),
            font: font,
            foregroundColor: foregroundColor,
            abbreviationColor: abbreviationColor,
            fixedVertical: fixedVertical
        ) { selection in
            appModel.toggleAbbreviationSelection(
                selection,
                for: textID.cardID
            )
        }
    }
}

/// Selectable inline presentation for Approved Abbreviations.
struct ClinicalAbbreviationText: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let text: String
    let textID: String
    let selection: AbbreviationSelection?
    let font: Font
    let foregroundColor: Color
    let abbreviationColor: Color
    let fixedVertical: Bool
    let onSelection: (AbbreviationSelection) -> Void

    init(
        _ text: String,
        textID: String,
        selection: AbbreviationSelection?,
        font: Font = .body,
        foregroundColor: Color = .primary,
        abbreviationColor: Color = .accentColor,
        fixedVertical: Bool = true,
        onSelection: @escaping (AbbreviationSelection) -> Void
    ) {
        self.text = text
        self.textID = textID
        self.selection = selection
        self.font = font
        self.foregroundColor = foregroundColor
        self.abbreviationColor = abbreviationColor
        self.fixedVertical = fixedVertical
        self.onSelection = onSelection
    }

    var body: some View {
        Text(attributedText)
            .font(font)
            .fixedSize(horizontal: false, vertical: fixedVertical)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.2),
                value: selection
            )
            .environment(\.openURL, OpenURLAction { url in
                guard let occurrence =
                    ClinicalAbbreviationGlossary.selection(from: url) else {
                    return .systemAction
                }

                onSelection(occurrence)
                return .handled
            })
    }

    private var attributedText: AttributedString {
        ClinicalAbbreviationGlossary.attributedString(
            for: text,
            textID: textID,
            selection: selection,
            baseColor: foregroundColor,
            abbreviationColor: abbreviationColor
        )
    }
}

struct ClinicalAbbreviationEntry: Identifiable, Hashable {
    let id: String
    let term: String
    let expansion: String
    let note: String?

    init(id: String, term: String, expansion: String, note: String? = nil) {
        self.id = id
        self.term = term
        self.expansion = expansion
        self.note = note
    }
}

enum ClinicalAbbreviationGlossary {
    static let urlScheme = "handover-abbreviation"

    // Vital-sign labels are intentionally omitted: HR, RR, MAP, SpO2 variants,
    // Temp, and BP should stay quiet in this handover UI.
    private static let definitions: [GlossaryDefinition] = [
        .init(
            entry: .init(id: "acf", term: "ACF", expansion: "Antecubital fossa"),
            aliases: []
        ),
        .init(
            entry: .init(id: "af", term: "AF", expansion: "Atrial fibrillation"),
            aliases: []
        ),
        .init(
            entry: .init(id: "aki", term: "AKI", expansion: "Acute kidney injury"),
            aliases: []
        ),
        .init(
            entry: .init(id: "alp", term: "ALP", expansion: "Alkaline phosphatase"),
            aliases: []
        ),
        .init(
            entry: .init(id: "alt", term: "ALT", expansion: "Alanine aminotransferase"),
            aliases: []
        ),
        .init(
            entry: .init(id: "ast", term: "AST", expansion: "Aspartate aminotransferase"),
            aliases: []
        ),
        .init(
            entry: .init(id: "bal", term: "BAL", expansion: "Bronchoalveolar lavage"),
            aliases: []
        ),
        .init(
            entry: .init(id: "bd", term: "BD", expansion: "Twice daily"),
            aliases: []
        ),
        .init(
            entry: .init(id: "bsl", term: "BSL", expansion: "Blood sugar level"),
            aliases: []
        ),
        .init(
            entry: .init(id: "cabg", term: "CABG", expansion: "Coronary artery bypass grafting"),
            aliases: []
        ),
        .init(
            entry: .init(id: "cmv", term: "CMV", expansion: "Cytomegalovirus"),
            aliases: []
        ),
        .init(
            entry: .init(id: "cpr", term: "CPR", expansion: "Cardiopulmonary resuscitation"),
            aliases: []
        ),
        .init(
            entry: .init(id: "cr", term: "Cr", expansion: "Creatinine"),
            aliases: []
        ),
        .init(
            entry: .init(id: "crp", term: "CRP", expansion: "C-reactive protein"),
            aliases: []
        ),
        .init(
            entry: .init(id: "crrt", term: "CRRT", expansion: "Continuous renal replacement therapy"),
            aliases: []
        ),
        .init(
            entry: .init(
                id: "cvvhdf",
                term: "CVVHDF",
                expansion: "Continuous veno-venous haemodiafiltration",
                note: "A CRRT mode that provides solute clearance and fluid removal."
            ),
            aliases: []
        ),
        .init(
            entry: .init(id: "cvc", term: "CVC", expansion: "Central venous catheter"),
            aliases: []
        ),
        .init(
            entry: .init(id: "cxr", term: "CXR", expansion: "Chest X-ray"),
            aliases: []
        ),
        .init(
            entry: .init(id: "c_and_s", term: "C&S", expansion: "Culture and sensitivity"),
            aliases: []
        ),
        .init(
            entry: .init(id: "ddx", term: "DDx", expansion: "Differential diagnosis"),
            aliases: ["DDX"]
        ),
        .init(
            entry: .init(id: "dka", term: "DKA", expansion: "Diabetic ketoacidosis"),
            aliases: []
        ),
        .init(
            entry: .init(id: "ecg", term: "ECG", expansion: "Electrocardiogram"),
            aliases: []
        ),
        .init(
            entry: .init(id: "en", term: "EN", expansion: "Enteral nutrition"),
            aliases: []
        ),
        .init(
            entry: .init(id: "gcs", term: "GCS", expansion: "Glasgow Coma Scale"),
            aliases: []
        ),
        .init(
            entry: .init(id: "hat", term: "HAT", expansion: "Hepatic artery thrombosis"),
            aliases: []
        ),
        .init(
            entry: .init(id: "hb", term: "Hb", expansion: "Haemoglobin"),
            aliases: []
        ),
        .init(
            entry: .init(id: "hco3", term: "HCO3", expansion: "Bicarbonate"),
            aliases: []
        ),
        .init(
            entry: .init(id: "hd", term: "HD", expansion: "Haemodialysis"),
            aliases: []
        ),
        .init(
            entry: .init(id: "id", term: "ID", expansion: "Infectious diseases"),
            aliases: []
        ),
        .init(
            entry: .init(id: "idc", term: "IDC", expansion: "Indwelling urinary catheter"),
            aliases: []
        ),
        .init(
            entry: .init(id: "ijv", term: "IJV", expansion: "Internal jugular vein"),
            aliases: []
        ),
        .init(
            entry: .init(id: "inr", term: "INR", expansion: "International normalized ratio"),
            aliases: []
        ),
        .init(
            entry: .init(id: "iv", term: "IV", expansion: "Intravenous"),
            aliases: []
        ),
        .init(
            entry: .init(id: "jp", term: "JP", expansion: "Jackson-Pratt drain"),
            aliases: []
        ),
        .init(
            entry: .init(id: "k_plus", term: "K+", expansion: "Potassium"),
            aliases: []
        ),
        .init(
            entry: .init(id: "lfts", term: "LFTs", expansion: "Liver function tests"),
            aliases: ["LFT"]
        ),
        .init(
            entry: .init(id: "lvef", term: "LVEF", expansion: "Left ventricular ejection fraction"),
            aliases: []
        ),
        .init(
            entry: .init(id: "mods", term: "MODS", expansion: "Multiple organ dysfunction syndrome"),
            aliases: []
        ),
        .init(
            entry: .init(id: "nacl", term: "NaCl", expansion: "Sodium chloride"),
            aliases: []
        ),
        .init(
            entry: .init(id: "nbm", term: "NBM", expansion: "Nil by mouth"),
            aliases: []
        ),
        .init(
            entry: .init(id: "ngt", term: "NGT", expansion: "Nasogastric tube"),
            aliases: []
        ),
        .init(
            entry: .init(id: "nsr", term: "NSR", expansion: "Normal sinus rhythm"),
            aliases: []
        ),
        .init(
            entry: .init(id: "od", term: "OD", expansion: "Once daily"),
            aliases: []
        ),
        .init(
            entry: .init(id: "pca", term: "PCA", expansion: "Patient-controlled analgesia"),
            aliases: []
        ),
        .init(
            entry: .init(id: "ph", term: "pH", expansion: "Acidity or alkalinity measurement"),
            aliases: []
        ),
        .init(
            entry: .init(id: "pf_ratio", term: "P/F", expansion: "PaO2/FiO2 ratio"),
            aliases: []
        ),
        .init(
            entry: .init(id: "qid", term: "QID", expansion: "Four times daily"),
            aliases: []
        ),
        .init(
            entry: .init(id: "q2h", term: "q2h", expansion: "Every 2 hours"),
            aliases: []
        ),
        .init(
            entry: .init(id: "q6h", term: "q6h", expansion: "Every 6 hours"),
            aliases: []
        ),
        .init(
            entry: .init(id: "ra", term: "RA", expansion: "Room air"),
            aliases: []
        ),
        .init(
            entry: .init(id: "rass", term: "RASS", expansion: "Richmond Agitation-Sedation Scale"),
            aliases: []
        ),
        .init(
            entry: .init(id: "ri", term: "RI", expansion: "Resistive index"),
            aliases: []
        ),
        .init(
            entry: .init(id: "rll", term: "RLL", expansion: "Right lower lobe"),
            aliases: []
        ),
        .init(
            entry: .init(id: "ruq", term: "RUQ", expansion: "Right upper quadrant"),
            aliases: []
        ),
        .init(
            entry: .init(id: "s_and_s", term: "S&S", expansion: "Swish and swallow"),
            aliases: []
        ),
        .init(
            entry: .init(id: "tds", term: "TDS", expansion: "Three times daily"),
            aliases: []
        ),
        .init(
            entry: .init(id: "t_tube", term: "T-tube", expansion: "Biliary drainage tube"),
            aliases: ["T tube"]
        ),
        .init(
            entry: .init(id: "uo", term: "UO", expansion: "Urine output"),
            aliases: []
        ),
        .init(
            entry: .init(id: "vas_cath", term: "Vas-Cath", expansion: "Vascular catheter"),
            aliases: []
        ),
        .init(
            entry: .init(id: "wbc", term: "WBC", expansion: "White blood cell count"),
            aliases: []
        )
    ]

    private static let entriesByID: [String: ClinicalAbbreviationEntry] = {
        Dictionary(uniqueKeysWithValues: definitions.map { ($0.entry.id, $0.entry) })
    }()

    private static let aliasToID: [String: String] = {
        var result: [String: String] = [:]

        for definition in definitions {
            for alias in [definition.entry.term] + definition.aliases {
                result[normalized(alias)] = definition.entry.id
            }
        }

        return result
    }()

    private static let matcher: NSRegularExpression = {
        let alternatives = aliasToID.keys
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs < rhs
                }
                return lhs.count > rhs.count
            }
            .map { NSRegularExpression.escapedPattern(for: $0) }
            .joined(separator: "|")

        let pattern = "(?<![A-Za-z0-9])(?:\(alternatives))(?![A-Za-z0-9])"
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    static func selection(from url: URL) -> AbbreviationSelection? {
        guard
            url.scheme == urlScheme,
            let glossaryEntryID = url.host,
            entriesByID[glossaryEntryID] != nil,
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let textID = components.queryItems?.first(where: { $0.name == "textID" })?.value,
            let occurrenceValue = components.queryItems?
                .first(where: { $0.name == "occurrence" })?
                .value,
            let occurrenceIndex = Int(occurrenceValue),
            occurrenceIndex >= 0
        else {
            return nil
        }

        return AbbreviationSelection(
            textID: textID,
            glossaryEntryID: glossaryEntryID,
            occurrenceIndex: occurrenceIndex
        )
    }

    static func occurrences(
        in text: String,
        textID: String
    ) -> [AbbreviationSelection] {
        matchedOccurrences(in: text).map { match in
            return AbbreviationSelection(
                textID: textID,
                glossaryEntryID: match.entry.id,
                occurrenceIndex: match.occurrenceIndex
            )
        }
    }

    static func attributedString(
        for text: String,
        textID: String,
        selection: AbbreviationSelection?,
        baseColor: Color,
        abbreviationColor: Color
    ) -> AttributedString {
        var result = AttributedString()
        let nsText = text as NSString
        var cursor = 0

        for match in matchedOccurrences(in: text) {
            guard match.range.location >= cursor else { continue }

            if match.range.location > cursor {
                append(
                    nsText.substring(with: NSRange(location: cursor, length: match.range.location - cursor)),
                    color: baseColor,
                    to: &result
                )
            }

            let occurrence = AbbreviationSelection(
                textID: textID,
                glossaryEntryID: match.entry.id,
                occurrenceIndex: match.occurrenceIndex
            )

            appendMatchedText(
                match.text,
                entry: match.entry,
                occurrence: occurrence,
                baseColor: baseColor,
                abbreviationColor: abbreviationColor,
                to: &result
            )

            if occurrence == selection {
                append(
                    " (\(match.entry.expansion))",
                    color: baseColor,
                    to: &result
                )
            }

            cursor = match.range.location + match.range.length
        }

        if cursor < nsText.length {
            append(
                nsText.substring(with: NSRange(location: cursor, length: nsText.length - cursor)),
                color: baseColor,
                to: &result
            )
        }

        return result
    }

    private static func matchedOccurrences(in text: String) -> [MatchedOccurrence] {
        let nsText = text as NSString
        let regexMatches = matcher.matches(
            in: text,
            options: [],
            range: NSRange(location: 0, length: nsText.length)
        )
        var occurrenceCounts: [String: Int] = [:]

        return regexMatches.compactMap { match in
            let matchedText = nsText.substring(with: match.range)
            guard let entry = entry(forMatchedText: matchedText) else {
                return nil
            }

            let occurrenceIndex = occurrenceCounts[entry.id, default: 0]
            occurrenceCounts[entry.id] = occurrenceIndex + 1
            return MatchedOccurrence(
                range: match.range,
                text: matchedText,
                entry: entry,
                occurrenceIndex: occurrenceIndex
            )
        }
    }

    private static func appendMatchedText(
        _ text: String,
        entry: ClinicalAbbreviationEntry,
        occurrence: AbbreviationSelection,
        baseColor: Color,
        abbreviationColor: Color,
        to result: inout AttributedString
    ) {
        guard let url = linkURL(for: entry, occurrence: occurrence) else {
            append(text, color: baseColor, to: &result)
            return
        }

        var fragment = AttributedString(text)
        fragment.foregroundColor = abbreviationColor
        // A link attribute gives only this occurrence native visionOS
        // gaze-and-pinch targeting and hover feedback.
        fragment.link = url
        fragment.underlineStyle = .single
        result += fragment
    }

    private static func linkURL(
        for entry: ClinicalAbbreviationEntry,
        occurrence: AbbreviationSelection
    ) -> URL? {
        var components = URLComponents()
        components.scheme = urlScheme
        components.host = entry.id
        components.queryItems = [
            URLQueryItem(name: "textID", value: occurrence.textID),
            URLQueryItem(
                name: "occurrence",
                value: String(occurrence.occurrenceIndex)
            )
        ]
        return components.url
    }

    private static func append(
        _ text: String,
        color: Color,
        to result: inout AttributedString
    ) {
        var fragment = AttributedString(text)
        fragment.foregroundColor = color
        result += fragment
    }

    private static func entry(forMatchedText text: String) -> ClinicalAbbreviationEntry? {
        guard let id = aliasToID[normalized(text)] else { return nil }
        return entriesByID[id]
    }

    private static func normalized(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    private struct GlossaryDefinition {
        let entry: ClinicalAbbreviationEntry
        let aliases: [String]
    }

    private struct MatchedOccurrence {
        let range: NSRange
        let text: String
        let entry: ClinicalAbbreviationEntry
        let occurrenceIndex: Int
    }

}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        ClinicalAbbreviationText(
            "Morphine PCA via IV (CVC). RASS -2. CXR: RLL consolidation. Continue CRRT (CVVHDF).",
            textID: "preview.clinical-abbreviations",
            selection: nil,
            font: .system(size: 14)
        ) { _ in }

        ClinicalAbbreviationText(
            "Vitals labels such as MAP, HR, RR, BP and SpO2 stay plain.",
            textID: "preview.excluded-vital-labels",
            selection: nil,
            font: .system(size: 14)
        ) { _ in }
    }
    .padding()
}
