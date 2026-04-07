//
//  TVGlassCard.swift
//  WiFi Check TV
//

import SwiftUI

struct TVGlassCard<Content: View>: View {
    let alignment: Alignment
    let content: Content

    init(alignment: Alignment = .topLeading, @ViewBuilder content: () -> Content) {
        self.alignment = alignment
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .background(Color.glassBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.glassBorder, lineWidth: 1)
            )
            .clipped()
    }
}
