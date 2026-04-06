import SwiftUI
import AVFoundation

// MARK: - Speech Controller

private final class StorySpeechController: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {

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

/// Detail view for a Memory/Story — follows the same layout as FamilyMemberProfileView.
struct MemoryStoryDetailView: View {

    let memory: Memory

    @StateObject private var speech = StorySpeechController()

    private var categoryColor: Color {
        switch memory.category {
        case .family:  return Color(red: 0.20, green: 0.40, blue: 0.85)
        case .events:  return Color(red: 0.85, green: 0.45, blue: 0.10)
        case .places:  return Color(red: 0.15, green: 0.60, blue: 0.35)
        case .other:   return Color(red: 0.45, green: 0.35, blue: 0.70)
        }
    }

    private var categoryIcon: String {
        switch memory.category {
        case .family:  return "heart.fill"
        case .events:  return "sparkles"
        case .places:  return "map.fill"
        case .other:   return "doc.text.fill"
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.backgroundDark.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    heroImage
                    titleSection
                    storySection
                    Spacer(minLength: 110)
                }
                .padding(.bottom, 16)
            }

            // Floating play button with fade — same pattern as FamilyMemberProfileView
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
        .navigationTitle(memory.title)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { speech.stop() }
    }

    // MARK: - Hero Image

    private var heroImage: some View {
        ZStack {
            if let ui = PersistenceService.loadImage(imageURL: memory.imageURL) {
                GeometryReader { geo in
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
                .frame(height: 300)
            } else {
                // Category-coloured placeholder
                ZStack {
                    LinearGradient(
                        colors: [categoryColor, categoryColor.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    Image(systemName: categoryIcon)
                        .font(.system(size: 64, weight: .bold))
                        .foregroundColor(.white.opacity(0.25))
                }
                .frame(height: 220)
            }
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(memory.title)
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.onSurface)

            HStack(spacing: 8) {
                Text(memory.category.rawValue.uppercased())
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(categoryColor)

                if !memory.date.isEmpty {
                    Text("\u{00B7}")
                        .foregroundColor(.onSurface.opacity(0.3))
                    Text(memory.date)
                        .font(.system(size: 14))
                        .foregroundColor(.onSurface.opacity(0.55))
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Story

    private var storySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("The Story")

            Text(memory.description.isEmpty
                 ? "No story written yet. Edit in Settings \u{2192} Memories & Stories."
                 : memory.description)
                .font(.system(size: 16))
                .foregroundColor(memory.description.isEmpty ? .onSurface.opacity(0.35) : .onSurface.opacity(0.85))
                .lineSpacing(4)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.surfaceVariant.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Play Button

    private var playButton: some View {
        let hasContent = !memory.description.isEmpty
        return Button {
            if hasContent { speech.toggle(text: memory.description) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: speech.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 22))
                Text(speech.isPlaying ? "Stop" : "Hear This Story")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(hasContent ? .backgroundDark : .onSurface.opacity(0.4))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(hasContent ? Color.accentYellow : Color.surfaceVariant.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(!hasContent)
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
        MemoryStoryDetailView(memory: UserProfile.sampleData.memories[0])
    }
    .preferredColorScheme(.dark)
}
