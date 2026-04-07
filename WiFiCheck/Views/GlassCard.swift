//
//  GlassCard.swift
//  WiFi Check v1
//

import SwiftUI

/// Reusable glassmorphism card — adapts to dark/light mode
struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.glassBackground)
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .fill(.ultraThinMaterial)
                            .opacity(0.3)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.glassBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}
