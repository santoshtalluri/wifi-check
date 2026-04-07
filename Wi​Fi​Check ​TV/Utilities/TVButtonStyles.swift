//
//  TVButtonStyles.swift
//  WiFi Check TV
//
//  Single source of truth for every interactive control style in the app.
//  All styles suppress the default white tvOS halo and provide polished
//  focus feedback that matches each component's own accent color.
//

import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - 1. Primary Action Button  (Scan Network / Test All Sites / Done)
//         Uses .borderedProminent — the native tvOS primary button look.
//         Caller sets .tint() to control fill color.
// ─────────────────────────────────────────────────────────────────────────────
// Use: Button("Scan") { }
//          .buttonStyle(.borderedProminent)
//          .tint(.scoreGood)
//          .controlSize(.large)


// ─────────────────────────────────────────────────────────────────────────────
// MARK: - 2. Segmented Selector  (5s / 15s / Manual)
//         Filled with accent color when selected.
//         Accent-colored border + scale when focused.
// ─────────────────────────────────────────────────────────────────────────────

struct TVSegmentButtonStyle: ButtonStyle {
    var isSelected: Bool
    var accentColor: Color
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(isFocused ? 1.08 : 1.0)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? accentColor : Color.white.opacity(isFocused ? 0.14 : 0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        isFocused ? accentColor : Color.clear,
                        lineWidth: 2
                    )
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isFocused)
            .focusEffectDisabled()
    }
}


// ─────────────────────────────────────────────────────────────────────────────
// MARK: - 3. Color Circle Selector
//         Ring = the circle's own color.  Spring bounce + glow on focus.
//         Selected (but not focused) = white checkmark badge.
// ─────────────────────────────────────────────────────────────────────────────

struct TVColorCircleStyle: ButtonStyle {
    var isSelected: Bool
    var circleColor: Color
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // Scale: focused > selected > normal
            .scaleEffect(isFocused ? 1.35 : (isSelected ? 1.12 : 1.0))
            // Colored ring outside the circle — expands via padding(-6)
            .overlay(
                Circle()
                    .stroke(
                        isFocused ? circleColor : (isSelected ? Color.white.opacity(0.9) : Color.clear),
                        lineWidth: isFocused ? 3.5 : 2.5
                    )
                    .padding(isFocused ? -7 : -5)
            )
            // Glow beneath the circle when focused
            .shadow(color: isFocused ? circleColor.opacity(0.7) : Color.clear,
                    radius: isFocused ? 12 : 0)
            // Checkmark badge when selected but not focused
            .overlay(alignment: .bottomTrailing) {
                if isSelected && !isFocused {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .background(Circle().fill(circleColor))
                        .offset(x: 4, y: 4)
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.55), value: isFocused)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isSelected)
            .focusEffectDisabled()
    }
}


// ─────────────────────────────────────────────────────────────────────────────
// MARK: - 4. Row Action Button  (Privacy Policy / Terms of Use rows)
//         Subtle fill + accent-tinted chevron on focus.
// ─────────────────────────────────────────────────────────────────────────────

struct TVRowActionStyle: ButtonStyle {
    var accentColor: Color = Color(hex: "0A84FF")
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isFocused ? accentColor.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isFocused ? accentColor.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
            .animation(.easeOut(duration: 0.15), value: isFocused)
            .focusEffectDisabled()
    }
}


// ─────────────────────────────────────────────────────────────────────────────
// MARK: - 5. Ghost Capsule Button  (Test All / Rescan inside cards)
//         Small, unobtrusive. Accent-colored border on focus.
// ─────────────────────────────────────────────────────────────────────────────

struct TVGhostCapsuleStyle: ButtonStyle {
    var accentColor: Color = .scoreGood
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(isFocused ? 1.06 : 1.0)
            .background(
                Capsule()
                    .fill(isFocused ? accentColor.opacity(0.18) : accentColor.opacity(0.10))
            )
            .overlay(
                Capsule()
                    .strokeBorder(isFocused ? accentColor : Color.clear, lineWidth: 1.5)
            )
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isFocused)
            .focusEffectDisabled()
    }
}


// ─────────────────────────────────────────────────────────────────────────────
// MARK: - 6. Empty-state scan prompt  (Tap to scan / no devices yet)
//         Focuses the whole area; accent glow on focus.
// ─────────────────────────────────────────────────────────────────────────────

struct TVScanPromptStyle: ButtonStyle {
    var accentColor: Color = .scoreGood
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(isFocused ? 1.04 : 1.0)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isFocused ? accentColor.opacity(0.6) : Color.clear, lineWidth: 1.5)
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isFocused)
            .focusEffectDisabled()
    }
}
