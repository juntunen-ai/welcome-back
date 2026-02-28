import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var appVM: AppViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundDark.ignoresSafeArea()

                List {
                    generalSection
                    aiSection
                    systemSection
                    footerSection
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
                .listRowSeparatorTint(Color.white.opacity(0.07))
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Sections

    private var generalSection: some View {
        Section {
            NavigationLink(destination: PersonalInfoView().environmentObject(appVM)) {
                SettingsRowView(icon: "person.fill", iconColor: .blue,
                                title: "Personal Info",
                                subtitle: "Name, address, biography")
            }
            .listRowBackground(Color.surfaceVariant.opacity(0.4))

            NavigationLink(destination: FamilyManagementView().environmentObject(appVM)) {
                SettingsRowView(
                    icon: "person.3.fill",
                    iconColor: .green,
                    title: "Family Members",
                    subtitle: "\(appVM.userProfile.familyMembers.count) member\(appVM.userProfile.familyMembers.count == 1 ? "" : "s")"
                )
            }
            .listRowBackground(Color.surfaceVariant.opacity(0.4))

            NavigationLink(destination: NotificationsSettingsView().environmentObject(appVM)) {
                SettingsRowView(icon: "bell.fill", iconColor: .red,
                                title: "Notifications",
                                subtitle: appVM.userProfile.notificationsEnabled ? "Enabled" : "Disabled")
            }
            .listRowBackground(Color.surfaceVariant.opacity(0.4))
        } header: {
            Text("General")
                .foregroundColor(.accentYellow)
                .font(.system(size: 12, weight: .bold))
                .tracking(1.5)
        }
    }

    private var aiSection: some View {
        Section {
            NavigationLink(destination: RecordVoiceView()) {
                SettingsRowView(
                    icon: "waveform.badge.mic",
                    iconColor: .accentYellow,
                    title: "Voice Cloning",
                    subtitle: "Coming Soon"
                )
            }
            .listRowBackground(Color.surfaceVariant.opacity(0.4))
        } header: {
            Text("Artificial Intelligence")
                .foregroundColor(.accentYellow)
                .font(.system(size: 12, weight: .bold))
                .tracking(1.5)
        }
    }

    private var systemSection: some View {
        Section {
            SettingsRowView(icon: "info.circle.fill", iconColor: .gray, title: "About", subtitle: "Version 1.0.0")
        } header: {
            Text("System")
                .foregroundColor(.accentYellow)
                .font(.system(size: 12, weight: .bold))
                .tracking(1.5)
        }
        .listRowBackground(Color.surfaceVariant.opacity(0.4))
    }

    private var footerSection: some View {
        Section {
            EmptyView()
        } footer: {
            VStack(spacing: 4) {
                Text("Welcome Back is powered by Google Gemini")
                    .font(.system(size: 12))
                    .foregroundColor(.onSurface.opacity(0.4))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
        .listRowBackground(Color.clear)
    }
}

// MARK: - Settings Row

struct SettingsRowView: View {

    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    var hasToggle: Bool = false
    var toggleBinding: Binding<Bool>? = nil

    var body: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 10)
                .fill(iconColor)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.onSurface)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.onSurface.opacity(0.5))
            }

            Spacer()

            if hasToggle, let binding = toggleBinding {
                Toggle("", isOn: binding)
                    .tint(.accentYellow)
                    .labelsHidden()
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppViewModel())
}
