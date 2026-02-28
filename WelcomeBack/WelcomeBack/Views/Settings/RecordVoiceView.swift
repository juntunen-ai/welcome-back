import SwiftUI

/// Voice cloning is planned for a future release.
/// This screen shows a roadmap preview while the feature is in development.
struct RecordVoiceView: View {

    var body: some View {
        ZStack {
            Color.backgroundDark.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    // Hero badge
                    ZStack {
                        Circle()
                            .fill(Color.accentYellow.opacity(0.12))
                            .frame(width: 120, height: 120)
                        Image(systemName: "waveform.badge.mic")
                            .font(.system(size: 52))
                            .foregroundColor(.accentYellow)
                    }
                    .padding(.top, 32)

                    VStack(spacing: 10) {
                        HStack(spacing: 8) {
                            Text("Voice Cloning")
                                .font(.system(size: 28, weight: .black))
                                .foregroundColor(.onSurface)

                            Text("Coming Soon")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.accentYellow)
                                .clipShape(Capsule())
                        }

                        Text("Imagine hearing a family member's story\nin their own voice.")
                            .font(.system(size: 16))
                            .foregroundColor(.onSurface.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 32)
                    }

                    // Feature preview cards
                    VStack(spacing: 14) {
                        featureCard(
                            icon: "mic.fill",            iconColor: .red,
                            title: "Record a voice sample",
                            description: "Caregivers record a short reading from a family member. Takes only 2 minutes.")
                        featureCard(
                            icon: "waveform",            iconColor: .purple,
                            title: "AI voice cloning",
                            description: "Our AI creates a unique voice model that sounds like your loved one.")
                        featureCard(
                            icon: "speaker.wave.2.fill", iconColor: .accentYellow,
                            title: "Hear familiar voices",
                            description: "Memory stories are spoken in the family member's own voice — not a generic AI.")
                    }
                    .padding(.horizontal, 24)

                    // Current state note
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.accentYellow)
                        Text("Currently, the AI uses a warm, natural voice for all stories. Voice cloning will be available in a future Premium update.")
                            .font(.system(size: 13))
                            .foregroundColor(.onSurface.opacity(0.55))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .background(Color.surfaceVariant.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.accentYellow.opacity(0.2)))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
                }
            }
        }
        .navigationTitle("Voice Cloning")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Helper

    private func featureCard(icon: String, iconColor: Color,
                              title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            RoundedRectangle(cornerRadius: 12)
                .fill(iconColor)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(iconColor == .accentYellow ? .black : .white)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.onSurface)
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.onSurface.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(Color.surfaceVariant.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18)
            .strokeBorder(Color.white.opacity(0.06)))
    }
}

#Preview {
    NavigationStack { RecordVoiceView() }
        .preferredColorScheme(.dark)
}
