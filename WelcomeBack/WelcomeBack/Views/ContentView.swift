import SwiftUI

struct ContentView: View {

    @EnvironmentObject private var appVM: AppViewModel

    var body: some View {
        TabView(selection: $appVM.selectedTab) {
            HomeView()
                .tabItem {
                    Label(AppTab.home.rawValue, systemImage: AppTab.home.icon)
                }
                .tag(AppTab.home)

            MemoriesView()
                .tabItem {
                    Label(AppTab.memories.rawValue, systemImage: AppTab.memories.icon)
                }
                .tag(AppTab.memories)

            FamilyView()
                .tabItem {
                    Label(AppTab.family.rawValue, systemImage: AppTab.family.icon)
                }
                .tag(AppTab.family)

            MusicView()
                .tabItem {
                    Label(AppTab.music.rawValue, systemImage: AppTab.music.icon)
                }
                .tag(AppTab.music)

            SettingsView()
                .tabItem {
                    Label(AppTab.settings.rawValue, systemImage: AppTab.settings.icon)
                }
                .tag(AppTab.settings)
        }
        .tint(.accentYellow)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppViewModel())
}
