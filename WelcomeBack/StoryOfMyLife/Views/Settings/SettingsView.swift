import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var appVM: AppViewModel
    @EnvironmentObject private var lang: LanguageManager
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
            .navigationTitle(lang.t("settings.title"))
            .navigationBarTitleDisplayMode(.large)
            .confirmationDialog(
                lang.t("settings.reset.confirm.title"),
                isPresented: $showResetConfirm,
                titleVisibility: .visible
            ) {
                Button(lang.t("settings.reset.confirm.action"), role: .destructive) {
                    appVM.resetToNewUser()
                }
                Button(lang.t("common.cancel"), role: .cancel) {}
            } message: {
                Text(lang.t("settings.reset.confirm.message"))
            }
        }
    }

    // MARK: - Sections

    private var generalSection: some View {
        Section {
            NavigationLink(destination: PersonalInfoView().environmentObject(appVM).environmentObject(lang)) {
                SettingsRowView(icon: "person.fill", iconColor: .blue,
                                title: lang.t("settings.personal.title"),
                                subtitle: lang.t("settings.personal.subtitle"))
            }
            .listRowBackground(Color.surfaceVariant.opacity(0.4))

            NavigationLink(destination: FamilyManagementView().environmentObject(appVM).environmentObject(lang)) {
                SettingsRowView(
                    icon: "person.3.fill",
                    iconColor: .green,
                    title: lang.t("settings.family.title"),
                    subtitle: lang.memberCount(appVM.userProfile.familyMembers.count)
                )
            }
            .listRowBackground(Color.surfaceVariant.opacity(0.4))

            NavigationLink(destination: PlacesManagementView().environmentObject(appVM).environmentObject(lang)) {
                SettingsRowView(
                    icon: "mappin.and.ellipse",
                    iconColor: .green,
                    title: lang.t("settings.places.title"),
                    subtitle: lang.placeCount(appVM.userProfile.places.count)
                )
            }
            .listRowBackground(Color.surfaceVariant.opacity(0.4))

            NavigationLink(destination: MemoriesManagementView().environmentObject(appVM).environmentObject(lang)) {
                SettingsRowView(
                    icon: "book.fill",
                    iconColor: .orange,
                    title: lang.t("settings.memories.title"),
                    subtitle: lang.memoryCount(appVM.userProfile.memories.count)
                )
            }
            .listRowBackground(Color.surfaceVariant.opacity(0.4))

            NavigationLink(destination: NotificationsSettingsView().environmentObject(appVM).environmentObject(lang)) {
                SettingsRowView(icon: "bell.fill", iconColor: .red,
                                title: lang.t("settings.notifications.title"),
                                subtitle: appVM.userProfile.notificationsEnabled
                                    ? lang.t("settings.notifications.enabled")
                                    : lang.t("settings.notifications.disabled"))
            }
            .listRowBackground(Color.surfaceVariant.opacity(0.4))

            NavigationLink(destination: LanguageSettingsView().environmentObject(lang)) {
                SettingsRowView(
                    icon: "globe",
                    iconColor: .teal,
                    title: lang.t("settings.language.title"),
                    subtitle: "\(lang.language.flag) \(lang.language.displayName)"
                )
            }
            .listRowBackground(Color.surfaceVariant.opacity(0.4))

        } header: {
            Text(lang.t("settings.section.general"))
                .foregroundColor(.accentYellow)
                .font(.system(size: 12, weight: .bold))
                .tracking(1.5)
        }
    }

    private var aiSection: some View {
        Section {
            NavigationLink(destination: ModelSettingsView().environmentObject(appVM).environmentObject(lang)) {
                SettingsRowView(
                    icon: "brain",
                    iconColor: .orange,
                    title: lang.t("settings.ai.model.title"),
                    subtitle: ModelDownloadService.shared.isModelReady
                        ? lang.t("settings.ai.model.ready")
                        : lang.t("settings.ai.model.not_downloaded")
                )
            }
            .listRowBackground(Color.surfaceVariant.opacity(0.4))

            NavigationLink(destination: VoiceModeSettingsView().environmentObject(appVM).environmentObject(lang)) {
                SettingsRowView(
                    icon: "speaker.wave.2.fill",
                    iconColor: .cyan,
                    title: lang.t("settings.ai.voice_mode.title"),
                    subtitle: lang.t("settings.ai.voice_mode.local")
                )
            }
            .listRowBackground(Color.surfaceVariant.opacity(0.4))

            NavigationLink(destination: VoiceSelectionView().environmentObject(lang)) {
                SettingsRowView(
                    icon: "speaker.wave.2.fill",
                    iconColor: .purple,
                    title: lang.t("settings.ai.companion.title"),
                    subtitle: SpeechService.shared.selectedVoiceIdentifier != nil
                        ? lang.t("settings.ai.companion.personal")
                        : lang.t("settings.ai.companion.default")
                )
            }
            .listRowBackground(Color.surfaceVariant.opacity(0.4))

        } header: {
            Text(lang.t("settings.section.ai"))
                .foregroundColor(.accentYellow)
                .font(.system(size: 12, weight: .bold))
                .tracking(1.5)
        }
    }

    private var systemSection: some View {
        Section {
            SettingsRowView(icon: "info.circle.fill", iconColor: .gray,
                            title: lang.t("settings.system.about.title"),
                            subtitle: lang.t("settings.system.about.subtitle"))
                .listRowBackground(Color.surfaceVariant.opacity(0.4))

            NavigationLink(destination: LicensesView().environmentObject(lang)) {
                SettingsRowView(icon: "doc.plaintext", iconColor: .gray,
                                title: lang.t("settings.system.licenses.title"),
                                subtitle: lang.t("settings.system.licenses.subtitle"))
            }
            .listRowBackground(Color.surfaceVariant.opacity(0.4))
        } header: {
            Text(lang.t("settings.section.system"))
                .foregroundColor(.accentYellow)
                .font(.system(size: 12, weight: .bold))
                .tracking(1.5)
        }
    }

    private var legalSection: some View {
        Section {
            NavigationLink(destination: LegalView(document: .privacyPolicy).environmentObject(lang)) {
                SettingsRowView(icon: "hand.raised.fill", iconColor: .blue,
                                title: lang.t("settings.legal.privacy.title"),
                                subtitle: lang.t("settings.legal.privacy.subtitle"))
            }
            .listRowBackground(Color.surfaceVariant.opacity(0.4))

            NavigationLink(destination: LegalView(document: .termsOfService).environmentObject(lang)) {
                SettingsRowView(icon: "doc.text.fill", iconColor: .gray,
                                title: lang.t("settings.legal.terms.title"),
                                subtitle: lang.t("settings.legal.terms.subtitle"))
            }
            .listRowBackground(Color.surfaceVariant.opacity(0.4))
        } header: {
            Text(lang.t("settings.section.legal"))
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
                                title: lang.t("settings.reset.title"),
                                subtitle: lang.t("settings.reset.subtitle"))
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.surfaceVariant.opacity(0.4))
        } header: {
            Text(lang.t("settings.section.reset"))
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
                Text(lang.t("settings.footer"))
                    .font(.system(size: 12))
                    .foregroundColor(.onSurface.opacity(0.4))

                if let url = URL(string: "https://juntunen.ai/storyofmylife/privacy") {
                    Link(lang.t("settings.privacy_link"), destination: url)
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
        .environmentObject(LanguageManager())
}
