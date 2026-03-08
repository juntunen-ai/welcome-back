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
            .animation(.easeInOut(duration: 0.45),
                       value: appViewModel.userProfile.isOnboardingComplete)
        }
    }
}
