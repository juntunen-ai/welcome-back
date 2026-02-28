import SwiftUI

/// Root container for the first-run onboarding experience.
/// Shown whenever `userProfile.isOnboardingComplete == false`.
struct OnboardingContainerView: View {

    @EnvironmentObject private var appVM: AppViewModel
    @State private var step: OnboardingStep = .welcome

    var body: some View {
        ZStack {
            Color.backgroundDark.ignoresSafeArea()

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

    private func advance() {
        switch step {
        case .welcome:     step = .profile
        case .profile:     step = .permissions
        case .permissions: step = .complete
        case .complete:    break
        }
    }
}

enum OnboardingStep {
    case welcome, profile, permissions, complete
}

extension OnboardingStep: Equatable {}
