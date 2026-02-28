import SwiftUI
import AVFoundation

// MARK: - Speech Controller

private final class SpeechController: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {

    @Published var isPlaying = false
    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func toggle(text: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        } else {
            let utterance = AVSpeechUtterance(string: text)
            utterance.rate = 0.48
            synthesizer.speak(utterance)
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    func speechSynthesizer(_ s: AVSpeechSynthesizer, didStart _: AVSpeechUtterance)  { isPlaying = true  }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish _: AVSpeechUtterance) { isPlaying = false }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel _: AVSpeechUtterance) { isPlaying = false }
}

// MARK: - View

struct FamilyMemberProfileView: View {

    let member: FamilyMember

    @StateObject private var speech = SpeechController()

    private var speechText: String {
        [member.biography, member.memory1, member.memory2]
            .filter { !$0.isEmpty }
            .joined(separator: ". ")
    }

    private var firstName: String {
        member.name.components(separatedBy: " ").first ?? member.name
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.backgroundDark.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    heroImage
                    nameSection
                    if !member.biography.isEmpty { biographySection }
                    if !member.memory1.isEmpty || !member.memory2.isEmpty { memoriesSection }
                    Spacer(minLength: 110)
                }
                .padding(.bottom, 16)
            }

            // Floating play button with fade
            if !speechText.isEmpty {
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [Color.backgroundDark.opacity(0), Color.backgroundDark],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 48)
                    .allowsHitTesting(false)

                    playButton
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                        .background(Color.backgroundDark)
                }
            }
        }
        .navigationTitle(member.name)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { speech.stop() }
    }

    // MARK: - Hero image

    private var heroImage: some View {
        Group {
            if let ui = PersistenceService.loadImage(imageURL: member.imageURL) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.surfaceVariant
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.onSurface.opacity(0.15))
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Name / relationship

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(member.name)
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.onSurface)

            if !member.relationship.isEmpty {
                Text(member.relationship.uppercased())
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(.accentYellow)
            }

            if !member.phone.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 12))
                    Text(member.phone)
                        .font(.system(size: 14))
                }
                .foregroundColor(.onSurface.opacity(0.55))
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Biography

    private var biographySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("About \(firstName)")

            Text(member.biography)
                .font(.system(size: 16))
                .foregroundColor(.onSurface.opacity(0.85))
                .lineSpacing(4)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.surfaceVariant.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Memories

    private var memoriesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Shared Memories")

            VStack(spacing: 12) {
                if !member.memory1.isEmpty {
                    memoryCard(text: member.memory1, accentColor: .accentYellow)
                }
                if !member.memory2.isEmpty {
                    memoryCard(text: member.memory2, accentColor: Color(red: 1, green: 0.6, blue: 0))
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func memoryCard(text: String, accentColor: Color) -> some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 10)
                .fill(accentColor)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "star.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                )
                .padding(.top, 2)

            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.onSurface.opacity(0.85))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceVariant.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Play button

    private var playButton: some View {
        Button { speech.toggle(text: speechText) } label: {
            HStack(spacing: 12) {
                Image(systemName: speech.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 22))
                Text(speech.isPlaying ? "Stop" : "Hear \(firstName)'s Story")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.backgroundDark)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.accentYellow)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Utility

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .foregroundColor(.accentYellow)
            .font(.system(size: 12, weight: .bold))
            .tracking(1.5)
            .textCase(.uppercase)
            .padding(.leading, 4)
    }
}

#Preview {
    NavigationStack {
        FamilyMemberProfileView(member: UserProfile.default.familyMembers[0])
    }
}
