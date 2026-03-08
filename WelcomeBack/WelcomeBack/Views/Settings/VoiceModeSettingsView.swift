import SwiftUI

/// Lets the user choose between cloud (Gemini) and local (llama.cpp) voice AI.
struct VoiceModeSettingsView: View {

    @EnvironmentObject private var appVM: AppViewModel

    var body: some View {
        ZStack {
            Color.backgroundDark.ignoresSafeArea()

            List {
                modeSection
                infoSection
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
            .listRowSeparatorTint(Color.white.opacity(0.07))
        }
        .navigationTitle("Voice Mode")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Mode Selection

    private var modeSection: some View {
        Section {
            // Cloud option
            Button {
                appVM.userProfile.preferredVoiceMode = .cloud
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: appVM.userProfile.preferredVoiceMode == .cloud
                          ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(appVM.userProfile.preferredVoiceMode == .cloud
                                         ? .accentYellow : .onSurface.opacity(0.3))
                        .font(.system(size: 20))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cloud (Gemini)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.onSurface)

                        Text("Uses Google Gemini via internet • Best quality")
                            .font(.system(size: 12))
                            .foregroundColor(.onSurface.opacity(0.5))
                    }

                    Spacer()
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.surfaceVariant.opacity(0.4))

            // Local option
            Button {
                if ModelDownloadService.shared.isModelReady {
                    appVM.userProfile.preferredVoiceMode = .local
                }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: appVM.userProfile.preferredVoiceMode == .local
                          ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(appVM.userProfile.preferredVoiceMode == .local
                                         ? .accentYellow : .onSurface.opacity(0.3))
                        .font(.system(size: 20))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Local (On-Device)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.onSurface)

                        Text("Runs entirely offline • Requires downloaded model")
                            .font(.system(size: 12))
                            .foregroundColor(.onSurface.opacity(0.5))
                    }

                    Spacer()

                    if !ModelDownloadService.shared.isModelReady {
                        Text("No Model")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .disabled(!ModelDownloadService.shared.isModelReady)
            .listRowBackground(Color.surfaceVariant.opacity(0.4))
        } header: {
            sectionHeader("Voice Mode")
        }
    }

    // MARK: - Info

    private var infoSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                infoRow(icon: "cloud.fill", color: .blue,
                        title: "Cloud Mode",
                        text: "Conversations are powered by Google Gemini over the internet. Offers the most natural, human-like responses. Requires an internet connection.")

                Divider().background(Color.white.opacity(0.1))

                infoRow(icon: "iphone", color: .green,
                        title: "Local Mode",
                        text: "Conversations run entirely on your iPhone using a downloaded AI model. Works offline. Download the model first in Voice AI Model settings.")
            }
            .padding(.vertical, 4)
            .listRowBackground(Color.surfaceVariant.opacity(0.4))
        } header: {
            sectionHeader("About")
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
    }
}
