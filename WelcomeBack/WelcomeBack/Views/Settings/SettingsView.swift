import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var appVM: AppViewModel
    @State private var showResetConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundDark.ignoresSafeArea()

                List {
                    generalSection
                    aiSection
                    systemSection
                    legalSection
                    resetSection
                    footerSection
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
                .listRowSeparatorTint(Color.white.opacity(0.07))
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .confirmationDialog(
                "Reset to New User?",
                isPresented: $showResetConfirm,
                titleVisibility: .visible
            ) {
                Button("Reset Everything", role: .destructive) {
                    appVM.resetToNewUser()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will erase all profile data, family members, and saved photos. The onboarding flow will restart. This cannot be undone.")
            }
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

            NavigationLink(destination: PlacesManagementView().environmentObject(appVM)) {
                SettingsRowView(
                    icon: "mappin.and.ellipse",
                    iconColor: .green,
                    title: "Places",
                    subtitle: "\(appVM.userProfile.places.count) place\(appVM.userProfile.places.count == 1 ? "" : "s")"
                )
            }
            .listRowBackground(Color.surfaceVariant.opacity(0.4))

            NavigationLink(destination: MemoriesManagementView().environmentObject(appVM)) {
                SettingsRowView(
                    icon: "book.fill",
                    iconColor: .orange,
                    title: "Memories & Stories",
                    subtitle: "\(appVM.userProfile.memories.count) memor\(appVM.userProfile.memories.count == 1 ? "y" : "ies")"
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
            NavigationLink(destination: ModelSettingsView().environmentObject(appVM)) {
                SettingsRowView(
                    icon: "brain",
                    iconColor: .orange,
                    title: "Voice AI Model",
                    subtitle: ModelDownloadService.shared.isModelReady ? "Ready" : "Not Downloaded"
                )
            }
            .listRowBackground(Color.surfaceVariant.opacity(0.4))

            // Voice mode toggle
            NavigationLink(destination: VoiceModeSettingsView().environmentObject(appVM)) {
                SettingsRowView(
                    icon: "speaker.wave.2.fill",
                    iconColor: .cyan,
                    title: "Voice Mode",
                    subtitle: "Local (On-Device)"
                )
            }
            .listRowBackground(Color.surfaceVariant.opacity(0.4))

            NavigationLink(destination: VoiceSelectionView()) {
                SettingsRowView(
                    icon: "speaker.wave.2.fill",
                    iconColor: .purple,
                    title: "Companion Voice",
                    subtitle: SpeechService.shared.selectedVoiceIdentifier != nil
                        ? "iOS Personal Voice" : "Default system voice"
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
                .listRowBackground(Color.surfaceVariant.opacity(0.4))

            NavigationLink(destination: LicensesView()) {
                SettingsRowView(icon: "doc.plaintext", iconColor: .gray,
                                title: "Open Source Licenses",
                                subtitle: "llama.cpp (MIT)")
            }
            .listRowBackground(Color.surfaceVariant.opacity(0.4))
        } header: {
            Text("System")
                .foregroundColor(.accentYellow)
                .font(.system(size: 12, weight: .bold))
                .tracking(1.5)
        }
    }

    private var legalSection: some View {
        Section {
            NavigationLink(destination: LegalView(document: .privacyPolicy)) {
                SettingsRowView(icon: "hand.raised.fill", iconColor: .blue,
                                title: "Privacy Policy",
                                subtitle: "How your data is handled")
            }
            .listRowBackground(Color.surfaceVariant.opacity(0.4))

            NavigationLink(destination: LegalView(document: .termsOfService)) {
                SettingsRowView(icon: "doc.text.fill", iconColor: .gray,
                                title: "Terms of Service",
                                subtitle: "Usage terms and disclaimers")
            }
            .listRowBackground(Color.surfaceVariant.opacity(0.4))
        } header: {
            Text("Legal")
                .foregroundColor(.accentYellow)
                .font(.system(size: 12, weight: .bold))
                .tracking(1.5)
        }
    }

    private var resetSection: some View {
        Section {
            Button {
                showResetConfirm = true
            } label: {
                SettingsRowView(icon: "arrow.counterclockwise", iconColor: .red,
                                title: "Reset to New User",
                                subtitle: "Erase all data and restart onboarding")
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.surfaceVariant.opacity(0.4))
        } header: {
            Text("Reset")
                .foregroundColor(.accentYellow)
                .font(.system(size: 12, weight: .bold))
                .tracking(1.5)
        }
    }

    private var footerSection: some View {
        Section {
            EmptyView()
        } footer: {
            VStack(spacing: 6) {
                Text("Welcome Back uses on-device AI to protect your privacy")
                    .font(.system(size: 12))
                    .foregroundColor(.onSurface.opacity(0.4))

                if let url = URL(string: "https://juntunen.ai/welcomeback/privacy") {
                    Link("Privacy Policy", destination: url)
                        .font(.system(size: 12))
                        .foregroundColor(.onSurface.opacity(0.3))
                }
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(subtitle)")
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppViewModel())
}
