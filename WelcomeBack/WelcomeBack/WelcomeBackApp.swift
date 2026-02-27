import SwiftUI

@main
struct WelcomeBackApp: App {

    @StateObject private var appViewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appViewModel)
                .preferredColorScheme(.dark)
        }
    }
}
