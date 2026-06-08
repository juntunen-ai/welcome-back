import SwiftUI

struct ContentView: View {

    @EnvironmentObject private var appVM: AppViewModel
    @EnvironmentObject private var lang: LanguageManager

    var body: some View {
        TabView(selection: $appVM.selectedTab) {
            HomeView()
                .tabItem {
                    Label(lang.t("tab.home"), systemImage: AppTab.home.icon)
                }
                .tag(AppTab.home)

            MemoriesView()
                .tabItem {
                    Label(lang.t("tab.memories"), systemImage: AppTab.memories.icon)
                }
                .tag(AppTab.memories)

            FamilyView()
                .tabItem {
                    Label(lang.t("tab.family"), systemImage: AppTab.family.icon)
                }
                .tag(AppTab.family)

            MusicView()
                .tabItem {
                    Label(lang.t("tab.music"), systemImage: AppTab.music.icon)
                }
                .tag(AppTab.music)

            SettingsView()
                .tabItem {
                    Label(lang.t("tab.settings"), systemImage: AppTab.settings.icon)
                }
                .tag(AppTab.settings)
        }
        .tint(.accentYellow)
        .onAppear {
            appVM.preloadLLMIfNeeded()
            Task {
                await ImageDescriptionService.shared.generateDescriptions(for: appVM.userProfile)
            }
        }
        .sheet(isPresented: $appVM.listeningSheetPresented) {
            ListeningView(mode: appVM.voiceMode)
                .environmentObject(appVM)
                .environmentObject(lang)
        }
        .sheet(item: $appVM.selectedFamilyMember) { member in
            PlaybackView(member: member)
                .environmentObject(appVM)
                .environmentObject(lang)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppViewModel())
        .environmentObject(LanguageManager())
}
