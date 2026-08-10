//
//  CardChrome.swift
//  Handover_V4
//
//  Shared container styling, empty state, divided row list, and trend arrow
//  used by every dashboard/spatial card, so card files only describe their
//  own content.
//

import SwiftUI

enum CardChrome {
    static let cornerRadius: CGFloat = 16

    /// Height of the tappable strip covering a Spatial Card's header bar
    /// (CardHeader) or, for a collapsed compact card, effectively the whole
    /// card. Matches the "Card Handle" surface described in CONTEXT.md.
    static let expansionTapAreaHeight: CGFloat = 52
}

extension View {
    /// The glass background and corner radius shared by every card container.
    func cardContainerBackground() -> some View {
        glassBackgroundEffect(in: .rect(cornerRadius: CardChrome.cornerRadius))
    }
}

/// Shared empty/all-clear state for a card's body: an icon, a secondary
/// message, and a trailing spacer.
struct CardEmptyState: View {
    let systemImage: String
    let message: String
    var iconColor: Color = .secondary

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(iconColor)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

/// A vertical list of rows separated by dividers, with no divider after the
/// last row. Matches the row-list layout shared by every card with a simple
/// itemized body.
struct DividedRowList<Data: RandomAccessCollection, RowContent: View>: View
where Data.Element: Identifiable {
    let data: Data
    @ViewBuilder let row: (Data.Element) -> RowContent

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(data.enumerated()), id: \.element.id) { index, element in
                row(element)

                if index < data.count - 1 {
                    Divider().padding(.horizontal, 16)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

extension Trend {
    var systemImageName: String {
        switch self {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .stable: return "arrow.right"
        }
    }
}

/// Shared trend indicator: an up/down/right arrow, or nothing when there's no
/// trend to show.
struct TrendArrowView: View {
    let trend: Trend?
    var fontSize: CGFloat = 11

    var body: some View {
        if let trend {
            Image(systemName: trend.systemImageName)
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(trend == .stable ? .tertiary : .secondary)
        } else {
            Color.clear
        }
    }
}
