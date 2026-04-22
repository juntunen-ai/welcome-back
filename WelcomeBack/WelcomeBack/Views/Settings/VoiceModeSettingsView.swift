import SwiftUI

/// Shows voice AI mode status and lets the user download the on-device model if needed.
/// Cloud (Gemini) mode is reserved for a future release and is not shown here.
struct VoiceModeSettingsView: View {

    @EnvironmentObject private var appVM: AppViewModel
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
        .navigationTitle("Voice Mode")
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
                    Text("Local (On-Device)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.onSurface)

                    Text("Runs entirely offline · No data leaves your phone")
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
                        Text("Gemma 4 Model Ready")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.onSurface)
                        Text("2.3 GB · Downloaded")
                            .font(.system(size: 12))
                            .foregroundColor(.onSurface.opacity(0.55))
                    }
                }
                .padding(.vertical, 4)
                .listRowBackground(Color.surfaceVariant.opacity(0.4))
            } else {
                NavigationLink(destination: ModelSettingsView().environmentObject(appVM)) {
                    HStack(spacing: 14) {
                        Image(systemName: "arrow.down.circle")
                            .foregroundColor(.orange)
                            .font(.system(size: 20))
                            .frame(width: 36, height: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Gemma 4 Model Not Downloaded")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.onSurface)
                            Text("Tap to download · 2.3 GB required")
                                .font(.system(size: 12))
                                .foregroundColor(.orange.opacity(0.85))
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.surfaceVariant.opacity(0.4))
            }

        } header: {
            sectionHeader("Active Mode")
        }
    }

    // MARK: - Info

    private var infoSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                infoRow(icon: "lock.shield.fill", color: .blue,
                        title: "Your Privacy",
                        text: "All conversations run entirely on your iPhone. No audio, no text, and no personal data is ever sent to external servers.")

                Divider().background(Color.white.opacity(0.1))

                infoRow(icon: "bolt.fill", color: .accentYellow,
                        title: "Works Offline",
                        text: "Once the Gemma 4 model is downloaded, Welcome Back works without any internet connection.")
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
    }
}
