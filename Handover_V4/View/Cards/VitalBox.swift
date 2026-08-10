//
//  VitalBox.swift
//  Handover_V4
//
//  Created by Juvern Khor on 30/4/2026.
//

//  Displays a single vital sign reading with:
//    - Label and trend arrow
//    - Current value + unit
//    - Sparkline of the last 12 hours
//    - 12-hour low – high range
//
//  Background colour is tinted by the VitalSign's status (.normal/.warning/.critical).
//

import SwiftUI

struct VitalBox: View {
    let vital: VitalSign
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Top row: label + trend arrow
            HStack {
                Text(vital.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                TrendArrowView(trend: vital.trend)
            }
            
            // Current value + unit
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(vital.value)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(vital.unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            // Sparkline
            Sparkline(data: vital.history, lineColor: statusColor)
                .frame(height: 36)
                .padding(.vertical, 2)
            
            // 12-hour range
            HStack(spacing: 4) {
                // Text("12h")
                //     .font(.system(size: 10))
                //     .foregroundStyle(.tertiary)
                Text(vital.rangeDisplay)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(statusBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(statusBorderColor, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Status-driven colours
    
    private var statusColor: Color {
        switch vital.status {
        case .normal:   return .green
        case .warning:  return .orange
        case .critical: return .red
        }
    }
    
    private var statusBackground: Color {
        switch vital.status {
        case .normal:   return Color.green.opacity(0.08)
        case .warning:  return Color.orange.opacity(0.10)
        case .critical: return Color.red.opacity(0.12)
        }
    }
    
    private var statusBorderColor: Color {
        switch vital.status {
        case .normal:   return Color.green.opacity(0.25)
        case .warning:  return Color.orange.opacity(0.35)
        case .critical: return Color.red.opacity(0.40)
        }
    }
}

// MARK: - Sparkline

/// A minimal sparkline drawn from a [Double] history.
/// Auto-scales vertically to fit the available height.
struct Sparkline: View {
    let data: [Double]
    let lineColor: Color
    
    var body: some View {
        GeometryReader { proxy in
            sparklinePath(in: proxy.size)
                .stroke(lineColor, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }
    
    private func sparklinePath(in size: CGSize) -> Path {
        Path { path in
            guard data.count > 1 else { return }
            
            let minVal = data.min() ?? 0
            let maxVal = data.max() ?? 1
            let range = max(maxVal - minVal, 0.0001)   // avoid divide-by-zero
            
            let xStep = size.width / CGFloat(data.count - 1)
            let usableHeight = size.height - 2          // leave 1pt padding top/bottom
            
            for (i, value) in data.enumerated() {
                let x = CGFloat(i) * xStep
                let normalized = (value - minVal) / range          // 0...1
                let y = usableHeight - CGFloat(normalized) * usableHeight + 1
                
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Single VitalBox") {
    VitalBox(vital: VitalSign(
        id: "preview",
        label: "HR",
        value: "88",
        unit: "bpm",
        status: .normal,
        timestamp: .now,
        history: [97, 95, 92, 89, 86, 84, 85, 87, 89, 90, 89, 88],
        trend: .down
    ))
    .frame(width: 160)
    .padding()
}

#Preview("All statuses") {
    HStack(spacing: 12) {
        VitalBox(vital: VitalSign(
            id: "1", label: "HR", value: "88", unit: "bpm",
            status: .normal, timestamp: .now,
            history: [97, 95, 92, 89, 86, 84, 85, 87, 89, 90, 89, 88],
            trend: .down
        ))
        VitalBox(vital: VitalSign(
            id: "2", label: "MAP", value: "70", unit: "mmHg",
            status: .warning, timestamp: .now,
            history: [76, 75, 74, 73, 72, 70, 69, 70, 71, 70, 70, 70],
            trend: .stable
        ))
        VitalBox(vital: VitalSign(
            id: "3", label: "SpO₂", value: "91", unit: "%",
            status: .critical, timestamp: .now,
            history: [94, 93, 93, 92, 92, 91, 91, 90, 91, 91, 91, 91],
            trend: .down
        ))
    }
    .frame(width: 540)
    .padding()
}
