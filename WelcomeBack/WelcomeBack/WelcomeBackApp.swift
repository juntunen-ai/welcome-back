import SwiftUI

@main
struct WelcomeBackApp: App {

    @StateObject private var appViewModel = AppViewModel()
    @StateObject private var languageManager = LanguageManager.shared

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
            .environmentObject(languageManager)
            .preferredColorScheme(.dark)
            .animation(.easeInOut(duration: 0.45),
                       value: appViewModel.userProfile.isOnboardingComplete)
        }
    }
}
