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
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Sections

    private var generalSection: some View {
        Section {
            SettingsRowView(icon: "person.fill", iconColor: .blue, title: "Personal Info", subtitle: "Manage your name and relations")
            SettingsRowView(icon: "bell.fill", iconColor: .red, title: "Notifications", subtitle: "Reminders to check in", hasToggle: true, toggleBinding: $appVM.userProfile.notificationsEnabled)
        } header: {
            Text("General")
                .foregroundColor(.accentYellow)
                .font(.system(size: 12, weight: .bold))
                .tracking(1.5)
        }
        .listRowBackground(Color.surfaceVariant.opacity(0.4))
    }

    private var aiSection: some View {
        Section {
            // Model picker
            HStack {
                Label {
                    Text("Core Model")
                        .foregroundColor(.onSurface)
                } icon: {
                    Image(systemName: "cpu.fill")
                        .foregroundColor(.purple)
                }

                Spacer()

                Picker("", selection: $appVM.userProfile.preferredAIModel) {
                    ForEach(AIModel.allCases, id: \.self) { model in
                        Text(model.rawValue).tag(model)
                    }
                }
                .pickerStyle(.menu)
                .tint(.accentYellow)
            }

            SettingsRowView(
                icon: "waveform.badge.mic",
                iconColor: .accentYellow,
                title: "Voice Cloning",
                subtitle: "\(appVM.userProfile.familyMembers.filter(\.isVoiceCloned).count) active personalities",
                hasToggle: true,
                toggleBinding: $appVM.userProfile.isVoiceCloningEnabled
            )
        } header: {
            Text("Artificial Intelligence")
                .foregroundColor(.accentYellow)
                .font(.system(size: 12, weight: .bold))
                .tracking(1.5)
        }
        .listRowBackground(Color.surfaceVariant.opacity(0.4))
    }

    private var systemSection: some View {
        Section {
            SettingsRowView(icon: "moon.fill", iconColor: .indigo, title: "Display", subtitle: "Dark mode")
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
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.onSurface.opacity(0.2))
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppViewModel())
}
