//
//  Cardheader.swift
//  Handover_V4
//
//  Created by Juvern Khor on 30/4/2026.
//
//
//  Reusable header bar for dashboard cards.
//  Contains the drag-handle grip icon and the card title.
//
//

import SwiftUI

struct CardHeader: View {
    let title: String
    var systemImage: String?      // optional icon next to title (e.g. "heart.fill")

    var body: some View {
        HStack(spacing: 8) {
            // Drag-handle grip icon (visual-only for now)
            Image(systemName: "line.3.horizontal")
                .hoverEffect(.lift)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary.opacity(0.5))
                .accessibilityHidden(true)

            // Optional leading icon
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            // Title
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    VStack(spacing: 16) {
        CardHeader(title: "Vitals", systemImage: "heart.fill")
        CardHeader(title: "Active infusions", systemImage: "drop.fill")
        CardHeader(title: "Treatment plan")
    }
    .padding()
}
