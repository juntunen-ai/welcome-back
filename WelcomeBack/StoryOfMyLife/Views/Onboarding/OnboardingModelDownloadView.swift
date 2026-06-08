import SwiftUI

/// Onboarding step that prompts the user to download the on-device Gemma 4 AI model.
struct OnboardingModelDownloadView: View {

    let onContinue: () -> Void

    @EnvironmentObject private var lang: LanguageManager
    @StateObject private var downloadService = ModelDownloadService.shared
    @State private var didAutoAdvance = false
    @State private var showCancelConfirm   = false
    @State private var showLowStorageAlert = false

    private var model: ModelDownloadService.ModelConfig { ModelDownloadService.defaultModel }

    // Required free space: model size (~3.1 GB) + 20 % buffer
    private let requiredBytes: Int64 = 3_800_000_000

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.accentYellow.opacity(0.12))
                    .frame(width: 130, height: 130)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 58))
                    .foregroundColor(.accentYellow)
            }
            .padding(.bottom, 28)

            // Title
            Text(lang.t("onboarding.model.title"))
                .font(.system(size: 32, weight: .black))
                .foregroundColor(.onSurface)
                .multilineTextAlignment(.center)
                .padding(.bottom, 10)

            Text(lang.t("onboarding.model.subtitle"))
                .font(.system(size: 16))
                .foregroundColor(.onSurface.opacity(0.6))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 32)
                .padding(.bottom, 36)

            // Model card
            modelCard
                .padding(.horizontal, 24)

            // Error message (if any)
            if let error = downloadService.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 32)
                .padding(.top, 12)
            }

            Spacer()

            bottomButtons
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
        }
        .onChange(of: downloadService.isModelReady) { _, ready in
            guard ready, !didAutoAdvance else { return }
            didAutoAdvance = true
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                onContinue()
            }
        }
        .onAppear {
            if downloadService.isModelReady, !didAutoAdvance {
                didAutoAdvance = true
                Task {
                    try? await Task.sleep(for: .seconds(0.8))
                    onContinue()
                }
            }
        }
        // Cancel confirmation
        .confirmationDialog(
            lang.t("onboarding.model.cancel.confirm.title"),
            isPresented: $showCancelConfirm,
            titleVisibility: .visible
        ) {
            Button(lang.t("onboarding.model.cancel.confirm.action"), role: .destructive) {
                downloadService.cancelDownload()
            }
            Button(lang.t("onboarding.model.cancel.continue"), role: .cancel) {}
        } message: {
            Text(lang.t("onboarding.model.cancel.confirm.message"))
        }
        // Low storage warning
        .alert(lang.t("onboarding.model.storage.title"), isPresented: $showLowStorageAlert) {
            Button(lang.t("common.ok"), role: .cancel) {}
            Button(lang.t("onboarding.model.storage.later")) { onContinue() }
        } message: {
            Text(lang.t("onboarding.model.storage.message"))
        }
    }

    // MARK: - Model card

    private var modelCard: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.85))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(model.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.onSurface)
                Text(String(format: lang.t("onboarding.model.card.subtitle"), model.sizeDescription))
                    .font(.system(size: 13))
                    .foregroundColor(.onSurface.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: downloadService.isModelReady ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundColor(downloadService.isModelReady ? .green : .onSurface.opacity(0.2))
        }
        .padding(16)
        .background(Color.surfaceVariant.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(
                    downloadService.isModelReady
                        ? Color.green.opacity(0.35)
                        : Color.white.opacity(0.06)
                )
        )
    }

    // MARK: - Bottom buttons

    @ViewBuilder
    private var bottomButtons: some View {
        if downloadService.isModelReady {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.black)
                Text(lang.t("onboarding.model.ready"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.accentYellow)
            .clipShape(Capsule())

        } else if downloadService.isDownloading {
            VStack(spacing: 14) {
                HStack {
                    Text(lang.t("onboarding.model.downloading"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.onSurface)
                    Spacer()
                    Text("\(Int(downloadService.downloadProgress * 100))%")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.accentYellow)
                }

                ProgressView(value: downloadService.downloadProgress)
                    .tint(.accentYellow)

                Button(lang.t("onboarding.model.cancel")) {
                    showCancelConfirm = true
                }
                .font(.system(size: 14))
                .foregroundColor(.red)
            }

        } else {
            Button {
                if downloadService.availableStorageBytes() < requiredBytes {
                    showLowStorageAlert = true
                } else {
                    downloadService.downloadModel(model)
                }
            } label: {
                Text(String(format: lang.t("onboarding.model.download.button"), model.sizeDescription))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.accentYellow)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(format: lang.t("onboarding.model.download.a11y"), model.sizeDescription))

            Button(action: onContinue) {
                Text(lang.t("onboarding.model.download.later"))
                    .font(.system(size: 15))
                    .foregroundColor(.onSurface.opacity(0.6))
                    .underline()
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            .accessibilityLabel(lang.t("onboarding.model.later.a11y"))
            .accessibilityHint(lang.t("onboarding.model.later.hint"))
        }
    }
}

#Preview {
    OnboardingModelDownloadView(onContinue: {})
        .environmentObject(LanguageManager())
        .preferredColorScheme(.dark)
}
