import SwiftUI

// MARK: - Step definition

enum OnboardingStep: Equatable {
    /// Pre-profile screens — no progress bar
    case welcome
    case language
    case modelDownload   // moved first: AI model before anything personal

    /// Core personal setup — progress bar starts here
    case profile         // name
    case photo           // user's own photo

    /// Content building — guided data entry with AI
    case addFamily
    case familyTip
    case addPlace
    case placeTip
    case addStory
    case storyTip

    /// Finish
    case music
    case complete
}

// MARK: - Container

/// Root container for the first-run onboarding experience.
/// Shown whenever `userProfile.isOnboardingComplete == false`.
struct OnboardingContainerView: View {

    @EnvironmentObject private var appVM: AppViewModel
    @EnvironmentObject private var lang: LanguageManager
    @State private var step: OnboardingStep = .welcome

    // Steps that show the progress indicator (excludes welcome / language / modelDownload / tips)
    private let progressSteps: [OnboardingStep] = [
        .profile, .photo, .addFamily, .addPlace, .addStory, .music, .complete
    ]

    var body: some View {
        ZStack(alignment: .top) {
            Color.backgroundDark.ignoresSafeArea()

            // Progress indicator — visible only on the main content steps
            if let idx = progressSteps.firstIndex(of: step) {
                progressBar(currentIndex: idx, total: progressSteps.count)
                    .padding(.top, 56)
                    .transition(.opacity)
            }

            // Step content
            Group {
                switch step {
                case .welcome:
                    OnboardingWelcomeView(onContinue: advance)
                case .language:
                    OnboardingLanguageView(onContinue: advance)
                case .modelDownload:
                    OnboardingModelDownloadView(onContinue: advance)
                case .profile:
                    OnboardingProfileView(onContinue: advance)
                case .photo:
                    OnboardingPhotoView(onContinue: advance)
                case .addFamily:
                    OnboardingAddFamilyView(onContinue: advance)
                case .familyTip:
                    OnboardingFamilyTipView(onContinue: advance)
                case .addPlace:
                    OnboardingAddPlaceView(onContinue: advance)
                case .placeTip:
                    OnboardingPlaceTipView(onContinue: advance)
                case .addStory:
                    OnboardingAddStoryView(onContinue: advance)
                case .storyTip:
                    OnboardingStoryTipView(onContinue: advance)
                case .music:
                    OnboardingMusicView(onContinue: advance)
                case .complete:
                    OnboardingCompleteView(onDone: { appVM.completeOnboarding() })
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing),
                removal:   .move(edge: .leading)))
        }
        .animation(.easeInOut(duration: 0.38), value: step)
    }

    // MARK: - Progress bar

    private func progressBar(currentIndex: Int, total: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { idx in
                Capsule()
                    .fill(idx <= currentIndex ? Color.accentYellow : Color.white.opacity(0.18))
                    .frame(width: idx == currentIndex ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.35), value: step)
            }
        }
    }

    // MARK: - Advance

    private func advance() {
        switch step {
        case .welcome:      step = .language
        case .language:     step = .modelDownload
        case .modelDownload: step = .profile
        case .profile:      step = .photo
        case .photo:        step = .addFamily
        case .addFamily:    step = .familyTip
        case .familyTip:    step = .addPlace
        case .addPlace:     step = .placeTip
        case .placeTip:     step = .addStory
        case .addStory:     step = .storyTip
        case .storyTip:     step = .music
        case .music:        step = .complete
        case .complete:     break
        }
    }
}
