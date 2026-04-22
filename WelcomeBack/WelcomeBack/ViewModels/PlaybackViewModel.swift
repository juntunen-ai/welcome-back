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
        do {
            story = try await GeminiService.shared.generateMemoryStory(
                userName: userName,
                familyMember: member
            )
        } catch {
            errorMessage = error.localizedDescription
            story = "Hi \(userName), it's \(member.name). We love you and are thinking of you."
        }
        isLoading = false
    }

    func togglePlayback() {
        if isPlaying {
            speechService.stopSpeaking()
            isPlaying = false
        } else {
            // Voice cloning is hidden for now — always use the system/personal voice.
            speechService.speak(story, voiceProfileID: nil)
            isPlaying = true
        }
    }

    func stopPlayback() {
        speechService.stopSpeaking()
        isPlaying = false
    }
}
