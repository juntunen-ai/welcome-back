import SwiftUI

@main
struct WelcomeBackApp: App {

    @StateObject private var appViewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if appViewModel.userProfile.isOnboardingComplete {
                    ContentView()
                } else {
                    OnboardingContainerView()
                }
            }
            .environmentObject(appViewModel)
            .preferredColorScheme(.dark)
            // Paywall sheet — presented on top of whichever root view is active
            .sheet(isPresented: $appViewModel.showPaywall) {
                PaywallView()
            }
            .animation(.easeInOut(duration: 0.45),
                       value: appViewModel.userProfile.isOnboardingComplete)
        }
    }
}
