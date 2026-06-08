import SwiftUI

/// Shows voice AI mode status and lets the user download the on-device model if needed.
/// Cloud (Gemini) mode is reserved for a future release and is not shown here.
struct VoiceModeSettingsView: View {

    @EnvironmentObject private var appVM: AppViewModel
    @EnvironmentObject private var lang: LanguageManager
    @StateObject private var downloadService = ModelDownloadService.shared

    var body: some View {
        ZStack {
            Color.backgroundDark.ignoresSafeArea()

            List {
                statusSection
                infoSection
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
            .listRowSeparatorTint(Color.white.opacity(0.07))
        }
        .navigationTitle(lang.t("settings.ai.voice_mode.title"))
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            // Ensure local is always selected (cloud path requires API key not yet configured)
            appVM.userProfile.preferredVoiceMode = .local
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        Section {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.green)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "iphone")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(lang.t("settings.ai.voice_mode.local"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.onSurface)

                    Text(lang.t("voicemode.offline_desc"))
                        .font(.system(size: 12))
                        .foregroundColor(.onSurface.opacity(0.55))
                }

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentYellow)
                    .font(.system(size: 20))
            }
            .padding(.vertical, 4)
            .listRowBackground(Color.surfaceVariant.opacity(0.4))

            // Model download state
            if downloadService.isModelReady {
                HStack(spacing: 14) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 20))
                        .frame(width: 36, height: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(lang.t("voicemode.model.ready"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.onSurface)
                        Text(lang.t("voicemode.model.ready.desc"))
                            .font(.system(size: 12))
                            .foregroundColor(.onSurface.opacity(0.55))
                    }
                }
                .padding(.vertical, 4)
                .listRowBackground(Color.surfaceVariant.opacity(0.4))
            } else {
                NavigationLink(destination: ModelSettingsView()
                    .environmentObject(appVM)
                    .environmentObject(lang)) {
                    HStack(spacing: 14) {
                        Image(systemName: "arrow.down.circle")
                            .foregroundColor(.orange)
                            .font(.system(size: 20))
                            .frame(width: 36, height: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(lang.t("voicemode.model.not_downloaded"))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.onSurface)
                            Text(lang.t("voicemode.model.download_hint"))
                                .font(.system(size: 12))
                                .foregroundColor(.orange.opacity(0.85))
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.surfaceVariant.opacity(0.4))
            }

        } header: {
            sectionHeader(lang.t("voicemode.active"))
        }
    }

    // MARK: - Info

    private var infoSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                infoRow(icon: "lock.shield.fill", color: .blue,
                        title: lang.t("voicemode.privacy.title"),
                        text: lang.t("voicemode.privacy.text"))

                Divider().background(Color.white.opacity(0.1))

                infoRow(icon: "bolt.fill", color: .accentYellow,
                        title: lang.t("voicemode.offline.title"),
                        text: lang.t("voicemode.offline.text"))
            }
            .padding(.vertical, 4)
            .listRowBackground(Color.surfaceVariant.opacity(0.4))
        } header: {
            sectionHeader(lang.t("voicemode.about"))
        }
    }

    // MARK: - Helpers

    private func infoRow(icon: String, color: Color, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 20, height: 20)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.onSurface)

                Text(text)
                    .font(.system(size: 13))
                    .foregroundColor(.onSurface.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .foregroundColor(.accentYellow)
            .font(.system(size: 12, weight: .bold))
            .tracking(1.5)
            .textCase(.uppercase)
    }
}

#Preview {
    NavigationStack {
        VoiceModeSettingsView()
            .environmentObject(AppViewModel())
            .environmentObject(LanguageManager())
    }
}
