//
//  TVSparkline.swift
//  WiFi Check TV
//

import SwiftUI

struct TVSparkline: View {
    let data: [Int]
    let accentColor: Color

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                RoundedRectangle(cornerRadius: 2)
                    .fill(accentColor)
                    .frame(width: 4, height: barHeight(for: value))
                    .opacity(opacity(for: index))
            }
        }
        .frame(height: 28)
    }

    private func barHeight(for value: Int) -> CGFloat {
        let maxVal = max(data.max() ?? 1, 1)
        return max(4, CGFloat(value) / CGFloat(maxVal) * 28)
    }

    private func opacity(for index: Int) -> Double {
        guard data.count > 1 else { return 1.0 }
        let progress = Double(index) / Double(data.count - 1)
        return 0.4 + (progress * 0.6)
    }
}
