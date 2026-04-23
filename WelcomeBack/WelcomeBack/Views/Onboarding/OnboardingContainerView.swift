import SwiftUI

/// Root container for the first-run onboarding experience.
/// Shown whenever `userProfile.isOnboardingComplete == false`.
struct OnboardingContainerView: View {

    @EnvironmentObject private var appVM: AppViewModel
    @State private var step: OnboardingStep = .welcome

    var body: some View {
        ZStack(alignment: .top) {
            Color.backgroundDark.ignoresSafeArea()

            // Progress dots — hidden on welcome screen
            if step != .welcome {
                progressDots
                    .padding(.top, 56)
                    .transition(.opacity)
            }

            switch step {
            case .welcome:
                OnboardingWelcomeView(onContinue: advance)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal:   .move(edge: .leading)))

            case .profile:
                OnboardingProfileView(onContinue: advance)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal:   .move(edge: .leading)))

            case .permissions:
                OnboardingPermissionsView(onContinue: advance)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal:   .move(edge: .leading)))

            case .modelDownload:
                OnboardingModelDownloadView(onContinue: advance)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal:   .move(edge: .leading)))

            case .complete:
                OnboardingCompleteView(onDone: {
                    appVM.completeOnboarding()
                })
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal:   .move(edge: .leading)))
            }
        }
        .animation(.easeInOut(duration: 0.38), value: step)
    }

    // MARK: - Progress dots

    /// Shows which of the 4 setup steps the user is on (excludes welcome screen).
    private var progressDots: some View {
        let steps: [OnboardingStep] = [.profile, .permissions, .modelDownload, .complete]
        let currentIndex = steps.firstIndex(of: step) ?? 0

        return HStack(spacing: 8) {
            ForEach(steps.indices, id: \.self) { idx in
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
        case .welcome:       step = .profile
        case .profile:       step = .permissions
        case .permissions:   step = .modelDownload
        case .modelDownload: step = .complete
        case .complete:      break
        }
    }
}

enum OnboardingStep {
    case welcome, profile, permissions, modelDownload, complete
}

extension OnboardingStep: Equatable {}
