import Foundation
import AVFoundation

@MainActor
final class PlaybackViewModel: ObservableObject {

    @Published var story: String = ""
    @Published var isLoading = true
    @Published var isPlaying = false
    @Published var errorMessage: String?

    private let speechService = SpeechService.shared
    private var member: FamilyMember?

    func loadStory(for member: FamilyMember, userName: String) async {
        self.member = member
        isLoading = true
        errorMessage = nil

        // Build a warm, personalised story from the data the caregiver entered.
        // GeminiService is not configured in this release (no API key); using a
        // template avoids a silent network failure and works offline.
        story = buildStory(for: member, userName: userName)

        isLoading = false
    }

    // MARK: - Story builder

    /// Assembles a natural-sounding message from the family member's profile data.
    private func buildStory(for member: FamilyMember, userName: String) -> String {
        var sentences: [String] = []

        sentences.append("Hi \(userName), it's \(member.name).")

        if !member.biography.isEmpty {
            sentences.append(member.biography)
        }

        if !member.memory1.isEmpty {
            sentences.append("I was just thinking about \(member.memory1)")
        }

        if !member.memory2.isEmpty {
            sentences.append("I also remember \(member.memory2)")
        }

        sentences.append("I love you and I'm thinking of you.")

        return sentences.joined(separator: " ")
    }

    // MARK: - Playback

    func togglePlayback() {
        if isPlaying {
            speechService.stopSpeaking()
            isPlaying = false
        } else {
            // Voice cloning is reserved for a future release — always use system/personal voice.
            speechService.speak(story, voiceProfileID: nil)
            isPlaying = true
        }
    }

    func stopPlayback() {
        speechService.stopSpeaking()
        isPlaying = false
    }
}
