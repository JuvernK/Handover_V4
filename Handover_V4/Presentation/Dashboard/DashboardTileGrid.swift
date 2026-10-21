// Flow: Clinical cards -> DashboardTileGrid -> DashboardTheme item surfaces.
import SwiftUI

/// Packs related dashboard records into readable tiles while preserving authored order.
/// Callers own clinical labels and values; this view owns spacing and responsive columns.
struct DashboardTileGrid<Item: Identifiable, Content: View>: View {
    let items: [Item]
    var minimumWidth: CGFloat = 240
    @ViewBuilder let content: (Item) -> Content
    @State private var availableWidth: CGFloat = 0

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: min(minimumWidth,
                                                          availableWidth > 0 ? availableWidth : minimumWidth)),
                                    spacing: 12, alignment: .top)],
                  alignment: .leading, spacing: 12) {
            ForEach(items) { item in
                content(item)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DashboardTheme.glassRaised, in: .rect(cornerRadius: 20))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(DashboardTheme.hairline, lineWidth: 1)
                            .allowsHitTesting(false)
                    }
                    .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }
    }
}
