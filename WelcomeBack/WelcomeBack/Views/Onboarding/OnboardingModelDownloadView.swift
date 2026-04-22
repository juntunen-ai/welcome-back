import SwiftUI

/// Onboarding step that prompts the user to download the on-device Gemma 4 AI model.
/// Placed between the permissions step and the completion screen.
/// Auto-advances once the download finishes; also allows skipping so the user
/// can download later from Settings → Voice AI Model.
struct OnboardingModelDownloadView: View {

    let onContinue: () -> Void

    @StateObject private var downloadService = ModelDownloadService.shared
    @State private var didAutoAdvance = false

    private var model: ModelDownloadService.ModelConfig { ModelDownloadService.defaultModel }

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
            Text("Download the AI")
                .font(.system(size: 32, weight: .black))
                .foregroundColor(.onSurface)
                .multilineTextAlignment(.center)
                .padding(.bottom, 10)

            Text("Welcome Back uses an on-device AI.\nYour conversations are completely private\nand work without internet.")
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
            // Brief pause so the user sees the checkmark, then advance.
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                onContinue()
            }
        }
        // If the model was already downloaded before this screen appeared, advance immediately.
        .onAppear {
            if downloadService.isModelReady, !didAutoAdvance {
                didAutoAdvance = true
                onContinue()
            }
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
                Text("Google on-device AI · \(model.sizeDescription) · Wi-Fi recommended")
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
            // Download just finished — show a ready state before auto-advancing.
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.black)
                Text("AI Ready!")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.accentYellow)
            .clipShape(Capsule())

        } else if downloadService.isDownloading {
            // Progress bar + cancel
            VStack(spacing: 14) {
                HStack {
                    Text("Downloading Gemma 4…")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.onSurface)
                    Spacer()
                    Text("\(Int(downloadService.downloadProgress * 100))%")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.accentYellow)
                }

                ProgressView(value: downloadService.downloadProgress)
                    .tint(.accentYellow)

                Button("Cancel Download") {
                    downloadService.cancelDownload()
                }
                .font(.system(size: 14))
                .foregroundColor(.red)
            }

        } else {
            // Not yet downloaded
            Button {
                downloadService.downloadModel(model)
            } label: {
                Text("Download Now · \(model.sizeDescription)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.accentYellow)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Download Gemma 4 AI model, \(model.sizeDescription)")

            Button(action: onContinue) {
                Text("Download later")
                    .font(.system(size: 15))
                    .foregroundColor(.onSurface.opacity(0.4))
                    .underline()
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            .accessibilityLabel("Skip model download and continue")
            .accessibilityHint("You can download the AI model later from Settings")
        }
    }
}

#Preview {
    OnboardingModelDownloadView(onContinue: {})
        .preferredColorScheme(.dark)
}
