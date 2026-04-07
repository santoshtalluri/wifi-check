// OnboardingView.swift
// Shown once on first launch. Forced dark mode, cinematic style.

import SwiftUI

// MARK: - Root Container

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0
    @State private var splashComplete = false
    private let totalPages = 3

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(red: 0.031, green: 0.043, blue: 0.078)
                .ignoresSafeArea()

            if splashComplete {
                // Full onboarding — fades in after splash
                TabView(selection: $currentPage) {
                    OnboardingSignalPage().tag(0)
                    OnboardingNetworkPage().tag(1)
                    OnboardingFreePage().tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea(edges: .top)
                .transition(.opacity)

                bottomControls
                    .transition(.opacity)
            } else {
                // Lightweight splash — renders in one frame, dismisses launch screen fast
                SplashRingsView()
            }
        }
        .preferredColorScheme(.dark)
        .task {
            // One frame to let SplashRingsView render and dismiss the launch screen,
            // then animate the full onboarding in after the rings have pulsed once.
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.easeInOut(duration: 0.5)) { splashComplete = true }
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 20) {
            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { i in
                    Capsule()
                        .fill(i == currentPage
                              ? Color(hex: "0A84FF")
                              : Color.white.opacity(0.22))
                        .frame(width: i == currentPage ? 22 : 8, height: 8)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: currentPage)
                }
            }

            Button(action: {
                if currentPage < totalPages - 1 {
                    withAnimation(.easeInOut(duration: 0.3)) { currentPage += 1 }
                } else {
                    hasSeenOnboarding = true
                }
            }) {
                Text(currentPage < totalPages - 1 ? "Next" : "Get Started")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(currentPage < totalPages - 1
                                  ? Color(hex: "0A84FF")
                                  : Color(hex: "30D158"))
                            .animation(.easeInOut(duration: 0.25), value: currentPage)
                    )
            }
            .padding(.horizontal, 32)
        }
        .padding(.bottom, 52)
    }
}

// MARK: - Splash (first frame, minimal, dismisses launch screen fast)

private struct SplashRingsView: View {
    @State private var ring1 = false
    @State private var ring2 = false
    @State private var ring3 = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(hex: "0A84FF").opacity(ring3 ? 0 : 0.10), lineWidth: 1)
                .frame(width: 220, height: 220)
                .scaleEffect(ring3 ? 1.5 : 1.0)
                .animation(.easeOut(duration: 2.3).repeatForever(autoreverses: false), value: ring3)

            Circle()
                .stroke(Color(hex: "0A84FF").opacity(ring2 ? 0 : 0.20), lineWidth: 1.5)
                .frame(width: 165, height: 165)
                .scaleEffect(ring2 ? 1.38 : 1.0)
                .animation(.easeOut(duration: 2.3).repeatForever(autoreverses: false), value: ring2)

            Circle()
                .stroke(Color(hex: "0A84FF").opacity(ring1 ? 0 : 0.38), lineWidth: 2)
                .frame(width: 118, height: 118)
                .scaleEffect(ring1 ? 1.28 : 1.0)
                .animation(.easeOut(duration: 2.3).repeatForever(autoreverses: false), value: ring1)

            ZStack {
                Circle()
                    .fill(Color(hex: "0A84FF").opacity(0.10))
                    .frame(width: 88, height: 88)
                    .blur(radius: 10)
                Circle()
                    .fill(Color(hex: "0A84FF").opacity(0.10))
                    .frame(width: 88, height: 88)
                Image(systemName: "wifi")
                    .font(.system(size: 34, weight: .light))
                    .foregroundColor(Color(hex: "0A84FF"))
            }
        }
        .onAppear {
            ring1 = true
            Task {
                try? await Task.sleep(for: .seconds(0.55))
                ring2 = true
                try? await Task.sleep(for: .seconds(0.55))
                ring3 = true
            }
        }
    }
}

// MARK: - Page 1: Signal Intelligence

private struct OnboardingSignalPage: View {
    @State private var ring1 = false
    @State private var ring2 = false
    @State private var ring3 = false
    @State private var textVisible = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color(hex: "0A84FF").opacity(ring3 ? 0 : 0.10), lineWidth: 1)
                    .frame(width: 220, height: 220)
                    .scaleEffect(ring3 ? 1.5 : 1.0)
                    .animation(.easeOut(duration: 2.3).repeatForever(autoreverses: false), value: ring3)

                Circle()
                    .stroke(Color(hex: "0A84FF").opacity(ring2 ? 0 : 0.20), lineWidth: 1.5)
                    .frame(width: 165, height: 165)
                    .scaleEffect(ring2 ? 1.38 : 1.0)
                    .animation(.easeOut(duration: 2.3).repeatForever(autoreverses: false), value: ring2)

                Circle()
                    .stroke(Color(hex: "0A84FF").opacity(ring1 ? 0 : 0.38), lineWidth: 2)
                    .frame(width: 118, height: 118)
                    .scaleEffect(ring1 ? 1.28 : 1.0)
                    .animation(.easeOut(duration: 2.3).repeatForever(autoreverses: false), value: ring1)

                ZStack {
                    Circle()
                        .fill(Color(hex: "0A84FF").opacity(0.10))
                        .frame(width: 88, height: 88)
                        .blur(radius: 10)
                    Circle()
                        .fill(Color(hex: "0A84FF").opacity(0.10))
                        .frame(width: 88, height: 88)
                    Image(systemName: "wifi")
                        .font(.system(size: 34, weight: .light))
                        .foregroundColor(Color(hex: "0A84FF"))
                }
            }
            .frame(height: 240)

            Spacer().frame(height: 44)

            VStack(spacing: 14) {
                Text("Know Your\nWiFi Signal")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                Text("A real-time quality score based on speed,\nlatency, and stability — right where you stand.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.48))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
            }
            .opacity(textVisible ? 1 : 0)
            .offset(y: textVisible ? 0 : 22)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
        .onAppear {
            ring1 = true
            Task {
                try? await Task.sleep(for: .seconds(0.55))
                ring2 = true
                try? await Task.sleep(for: .seconds(0.55))
                ring3 = true
            }
            Task {
                try? await Task.sleep(for: .seconds(0.2))
                withAnimation(.easeOut(duration: 0.7)) { textVisible = true }
            }
        }
    }
}

// MARK: - Page 2: Network Scanner

private struct OnboardingNetworkPage: View {
    @State private var visibleCount = 0
    @State private var textVisible = false

    private let devices: [(icon: String, label: String, color: String)] = [
        ("wifi.router.fill",  "Router",      "0A84FF"),
        ("iphone",            "iPhone",      "30D158"),
        ("laptopcomputer",    "MacBook",     "30D158"),
        ("appletv.fill",      "Apple TV",    "BF5AF2"),
        ("printer.fill",      "Printer",     "FF9F0A"),
        ("homekit",           "Smart Home",  "FF9F0A"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                spacing: 22
            ) {
                ForEach(Array(devices.enumerated()), id: \.offset) { idx, dev in
                    VStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(hex: dev.color).opacity(0.13))
                                .frame(width: 68, height: 68)
                            Image(systemName: dev.icon)
                                .font(.system(size: 27))
                                .foregroundColor(Color(hex: dev.color))
                        }
                        Text(dev.label)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.48))
                    }
                    .opacity(visibleCount > idx ? 1 : 0)
                    .scaleEffect(visibleCount > idx ? 1 : 0.5)
                    .animation(
                        .spring(response: 0.42, dampingFraction: 0.66),
                        value: visibleCount > idx
                    )
                }
            }
            .padding(.horizontal, 28)

            Spacer().frame(height: 44)

            VStack(spacing: 14) {
                Text("See Every Device\non Your Network")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                Text("Phones, TVs, computers, smart home —\nidentified and grouped automatically.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.48))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
            }
            .opacity(textVisible ? 1 : 0)
            .offset(y: textVisible ? 0 : 22)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
        .onAppear {
            visibleCount = 0
            textVisible = false
            Task {
                for i in 0..<devices.count {
                    try? await Task.sleep(for: .seconds(Double(i) * 0.13 + 0.1))
                    visibleCount = i + 1
                }
            }
            Task {
                try? await Task.sleep(for: .seconds(1.0))
                withAnimation(.easeOut(duration: 0.7)) { textVisible = true }
            }
        }
        .onDisappear {
            visibleCount = 0
            textVisible = false
        }
    }
}

// MARK: - Page 3: Free

private struct OnboardingFreePage: View {
    @State private var iconVisible = false
    @State private var textVisible = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color(hex: "30D158").opacity(0.10))
                    .frame(width: 130, height: 130)
                    .blur(radius: 14)
                    .scaleEffect(iconVisible ? 1.15 : 0.3)
                    .opacity(iconVisible ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.65).delay(0.04), value: iconVisible)

                Circle()
                    .fill(Color(hex: "30D158").opacity(0.11))
                    .frame(width: 118, height: 118)
                    .scaleEffect(iconVisible ? 1 : 0.3)
                    .opacity(iconVisible ? 1 : 0)
                    .animation(.spring(response: 0.55, dampingFraction: 0.65), value: iconVisible)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 54))
                    .foregroundColor(Color(hex: "30D158"))
                    .scaleEffect(iconVisible ? 1 : 0.25)
                    .opacity(iconVisible ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1), value: iconVisible)
            }
            .frame(height: 150)

            Spacer().frame(height: 44)

            VStack(spacing: 14) {
                Text("100% Free.\nNo Catches.")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                Text("No ads. No subscription.\nNo mysterious emails three weeks later.\nJust your WiFi, analyzed.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.48))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
            }
            .opacity(textVisible ? 1 : 0)
            .offset(y: textVisible ? 0 : 22)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
        .onAppear {
            withAnimation { iconVisible = true }
            Task {
                try? await Task.sleep(for: .seconds(0.3))
                withAnimation(.easeOut(duration: 0.7)) { textVisible = true }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
}
