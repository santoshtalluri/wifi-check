//
//  SupportSheet.swift
//  WiFi Check v1
//

import SwiftUI
import MessageUI
import PhotosUI

/// Support sheet with 3 categories: Bug Report, Feature Request, General Question
/// Each category has a text input and submit button that opens MFMailComposeViewController
struct SupportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedCategory: SupportCategory?
    @State private var messageText: String = ""

    init(preselectedCategory: SupportCategory? = nil) {
        _selectedCategory = State(initialValue: preselectedCategory)
    }
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var screenshotData: Data?
    @State private var screenshotImage: UIImage?
    @State private var showMailComposer = false
    @State private var showNoMailAlert = false

    enum SupportCategory: String, CaseIterable {
        case bug = "Bug Report"
        case feature = "Feature Request"
        case question = "General Question"

        var accessibilityID: String {
            switch self {
            case .bug: return "bug"
            case .feature: return "feature"
            case .question: return "question"
            }
        }
    }

    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    // Category cards
                    bugCard
                    featureCard
                    questionCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color.appBackground)
            .navigationTitle("Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.textSecondary)
                }
            }
        }
        .sheet(isPresented: $showMailComposer) {
            MailComposerView(
                category: selectedCategory ?? .bug,
                messageText: messageText,
                screenshotData: screenshotData
            ) {
                // On dismiss — clear form
                messageText = ""
                screenshotData = nil
                screenshotImage = nil
                selectedPhoto = nil
                selectedCategory = nil
            }
        }
        .alert("Mail Not Configured", isPresented: $showNoMailAlert) {
            Button("Copy Email") {
                UIPasteboard.general.string = "contact@wifi-check.app"
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your device doesn't have Mail set up. You can email us directly at contact@wifi-check.app")
        }
        .onChange(of: selectedPhoto) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    screenshotData = data
                    screenshotImage = UIImage(data: data)
                }
            }
        }
    }

    // MARK: - Bug Report Card

    private var bugCard: some View {
        supportCard(
            category: .bug,
            icon: "ladybug.fill",
            iconColor: .scorePoor,
            heading: "Having an issue?",
            subtitle: "Describe what went wrong and we'll look into it",
            showScreenshot: true
        )
    }

    // MARK: - Feature Request Card

    private var featureCard: some View {
        supportCard(
            category: .feature,
            icon: "lightbulb.fill",
            iconColor: .scoreFair,
            heading: "Got a great idea?",
            subtitle: "Tell us what feature you think is missing",
            showScreenshot: false
        )
    }

    // MARK: - General Question Card

    private var questionCard: some View {
        supportCard(
            category: .question,
            icon: "questionmark.bubble.fill",
            iconColor: .scoreExcellent,
            heading: "Got a question? We're here to help",
            subtitle: "Ask us anything about WiFi Check",
            showScreenshot: false
        )
    }

    // MARK: - Reusable Card

    private func supportCard(
        category: SupportCategory,
        icon: String,
        iconColor: Color,
        heading: String,
        subtitle: String,
        showScreenshot: Bool
    ) -> some View {
        let isExpanded = selectedCategory == category

        return VStack(alignment: .leading, spacing: 0) {
            // Header — always visible, tappable
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    if selectedCategory == category {
                        selectedCategory = nil
                    } else {
                        selectedCategory = category
                        messageText = ""
                        screenshotData = nil
                        screenshotImage = nil
                        selectedPhoto = nil
                    }
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(iconColor)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(heading)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.textPrimary)
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(16)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("supportCard_\(category.accessibilityID)")

            // Expanded form
            if isExpanded {
                Divider().background(Color.dividerColor).padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 12) {
                    // Category tag
                    Text(category.rawValue.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.8)
                        .foregroundColor(iconColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(iconColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    // Text input
                    ZStack(alignment: .topLeading) {
                        if messageText.isEmpty {
                            Text("Describe your \(category == .bug ? "issue" : category == .feature ? "idea" : "question")...")
                                .font(.system(size: 14))
                                .foregroundColor(.textTertiary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                        }
                        TextEditor(text: $messageText)
                            .font(.system(size: 14))
                            .foregroundColor(.textPrimary)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 100)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.dividerColor, lineWidth: 1)
                    )

                    // Screenshot picker (bug reports only)
                    if showScreenshot {
                        HStack(spacing: 8) {
                            PhotosPicker(selection: $selectedPhoto, matching: .screenshots) {
                                HStack(spacing: 6) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 12))
                                    Text(screenshotImage != nil ? "Screenshot attached" : "Attach Screenshot")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundColor(screenshotImage != nil ? .scoreGood : .textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
                                )
                            }

                            if screenshotImage != nil {
                                Button(action: {
                                    screenshotData = nil
                                    screenshotImage = nil
                                    selectedPhoto = nil
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.textTertiary)
                                }
                            }
                        }
                    }

                    // Submit button
                    Button(action: {
                        submitForm(category: category)
                    }) {
                        Text("Submit")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                          ? Color.textTertiary
                                          : Color.scoreExcellent)
                            )
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("submitSupportButton")
                }
                .padding(16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(colorScheme == .dark
                      ? Color.white.opacity(0.055)
                      : Color(red: 242/255, green: 242/255, blue: 247/255).opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(colorScheme == .dark
                                ? Color.white.opacity(0.10)
                                : Color.black.opacity(0.08),
                                lineWidth: 0.5)
                )
        )
    }

    // MARK: - Submit

    private func submitForm(category: SupportCategory) {
        selectedCategory = category
        if MFMailComposeViewController.canSendMail() {
            showMailComposer = true
        } else {
            showNoMailAlert = true
        }
    }
}

// MARK: - MFMailComposeViewController Wrapper

struct MailComposerView: UIViewControllerRepresentable {
    let category: SupportSheet.SupportCategory
    let messageText: String
    let screenshotData: Data?
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients(["contact@wifi-check.app"])

        let subject: String
        switch category {
        case .bug: subject = "[WiFi Check] Bug Report"
        case .feature: subject = "[WiFi Check] Feature Request"
        case .question: subject = "[WiFi Check] Question"
        }
        composer.setSubject(subject)
        composer.setMessageBody(messageText, isHTML: false)

        if let data = screenshotData {
            composer.addAttachmentData(data, mimeType: "image/png", fileName: "screenshot.png")
        }

        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) { }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onDismiss: () -> Void

        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true) {
                self.onDismiss()
            }
        }
    }
}
