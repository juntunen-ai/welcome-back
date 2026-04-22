import SwiftUI

/// Displays the Privacy Policy or Terms of Service.
/// Opens the hosted URL in Safari; includes an offline fallback summary.
struct LegalView: View {

    enum LegalDocument: String {
        case privacyPolicy = "Privacy Policy"
        case termsOfService = "Terms of Service"

        var url: URL? {
            switch self {
            case .privacyPolicy:
                return URL(string: "https://juntunen.ai/welcomeback/privacy")
            case .termsOfService:
                return URL(string: "https://juntunen.ai/welcomeback/terms")
            }
        }
    }

    let document: LegalDocument

    var body: some View {
        ZStack {
            Color.backgroundDark.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let url = document.url {
                        Link(destination: url) {
                            HStack {
                                Image(systemName: "safari")
                                Text("Open in Safari")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.accentYellow)
                        }
                        .padding(.bottom, 8)
                    }

                    switch document {
                    case .privacyPolicy:
                        privacyPolicySummary
                    case .termsOfService:
                        termsOfServiceSummary
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle(document.rawValue)
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Privacy Policy Summary

    private var privacyPolicySummary: some View {
        VStack(alignment: .leading, spacing: 16) {
            legalSection(title: "What Data We Collect") {
                """
                Welcome Back stores your personal profile (name, address, biography), \
                family member information, memory descriptions, and photos. All data is \
                stored locally on your device.
                """
            }

            legalSection(title: "How Data Is Used") {
                """
                Your data is used solely to provide personalised AI conversations and \
                memory assistance. Profile information is included in AI prompts so the \
                companion can reference your family, memories, and personal details naturally.
                """
            }

            legalSection(title: "On-Device AI Processing") {
                """
                All AI conversations are processed entirely on your device using a \
                downloaded language model (Gemma 4). Your voice, messages, and personal \
                data never leave your iPhone. No data is sent to any external server \
                during AI conversations.
                """
            }

            legalSection(title: "Data Security") {
                """
                All personal data is encrypted at rest using iOS Data Protection. \
                Network communications use HTTPS/TLS encryption.
                """
            }

            legalSection(title: "Your Rights") {
                """
                You can delete all your data at any time using "Reset to New User" \
                in Settings. This permanently removes your profile, family members, \
                photos, and all cached data from the device.
                """
            }

            legalSection(title: "Contact") {
                "For questions about your privacy, contact us at privacy@juntunen.ai."
            }

            Text("Last updated: April 2026")
                .font(.system(size: 12))
                .foregroundColor(.onSurface.opacity(0.4))
        }
    }

    // MARK: - Terms of Service Summary

    private var termsOfServiceSummary: some View {
        VStack(alignment: .leading, spacing: 16) {
            legalSection(title: "Acceptance") {
                """
                By using Welcome Back, you agree to these terms. If you do not agree, \
                please discontinue use.
                """
            }

            legalSection(title: "Purpose") {
                """
                Welcome Back is a companion app designed to support memory recall through \
                AI-assisted conversations. It is not a medical device and does not provide \
                medical advice, diagnosis, or treatment.
                """
            }

            legalSection(title: "Medical Disclaimer") {
                """
                This app is not a substitute for professional medical care. If you or \
                someone you care for has concerns about memory or cognitive health, \
                please consult a qualified healthcare professional.
                """
            }

            legalSection(title: "AI-Generated Content") {
                """
                Responses from the AI companion are generated by language models and may \
                not always be accurate. The app uses your personal data to provide \
                contextual responses but cannot guarantee factual correctness.
                """
            }

            legalSection(title: "User Responsibility") {
                """
                You are responsible for the accuracy of the personal information you \
                enter. The app relies on this information to provide meaningful \
                conversations.
                """
            }

            legalSection(title: "Intellectual Property") {
                """
                Welcome Back and its original content are owned by Juntunen AI. \
                The app uses open-source components including llama.cpp (MIT License).
                """
            }

            Text("Last updated: April 2026")
                .font(.system(size: 12))
                .foregroundColor(.onSurface.opacity(0.4))
        }
    }

    // MARK: - Helper

    private func legalSection(title: String, content: () -> String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.onSurface)

            Text(content())
                .font(.system(size: 14))
                .foregroundColor(.onSurface.opacity(0.7))
                .lineSpacing(3)
        }
    }
}
