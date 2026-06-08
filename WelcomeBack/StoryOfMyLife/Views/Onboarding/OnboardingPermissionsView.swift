import SwiftUI
import Photos
import AVFoundation

struct OnboardingPermissionsView: View {

    let onContinue: () -> Void

    @EnvironmentObject private var lang: LanguageManager
    @State private var micGranted    = false
    @State private var photosGranted = false
    @State private var isRequesting  = false
    @State private var showSettingsAlert = false

    var allGranted: Bool { micGranted && photosGranted }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            Image(systemName: "lock.open.fill")
                .font(.system(size: 56))
                .foregroundColor(.accentYellow)
                .padding(.bottom, 24)

            // Title
            Text(lang.t("onboarding.permissions.title"))
                .font(.system(size: 32, weight: .black))
                .foregroundColor(.onSurface)
                .multilineTextAlignment(.center)
                .padding(.bottom, 10)

            Text(lang.t("onboarding.permissions.subtitle"))
                .font(.system(size: 16))
                .foregroundColor(.onSurface.opacity(0.6))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 32)
                .padding(.bottom, 40)

            // Permission cards
            VStack(spacing: 14) {
                permissionCard(
                    icon: "mic.fill",
                    iconColor: .red,
                    title: lang.t("onboarding.permissions.mic.title"),
                    description: lang.t("onboarding.permissions.mic.desc"),
                    granted: micGranted
                )
                permissionCard(
                    icon: "photo.on.rectangle",
                    iconColor: .blue,
                    title: lang.t("onboarding.permissions.photos.title"),
                    description: lang.t("onboarding.permissions.photos.desc"),
                    granted: photosGranted
                )
            }
            .padding(.horizontal, 24)

            Spacer()

            // Primary button
            Button(action: requestAll) {
                HStack(spacing: 10) {
                    if isRequesting {
                        ProgressView()
                            .tint(.black)
                    }
                    Text(isRequesting ? lang.t("onboarding.permissions.requesting")
                         : allGranted  ? lang.t("common.continue")
                         : lang.t("onboarding.permissions.allow"))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.accentYellow)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isRequesting)
            .padding(.horizontal, 32)
            .padding(.bottom, 12)
            .accessibilityLabel(allGranted
                ? lang.t("common.continue")
                : lang.t("onboarding.permissions.allow.a11y"))

            Button(action: onContinue) {
                Text(lang.t("onboarding.permissions.skip"))
                    .font(.system(size: 15))
                    .foregroundColor(.onSurface.opacity(0.6))
                    .underline()
            }
            .buttonStyle(.plain)
            .padding(.bottom, 48)
            .accessibilityLabel(lang.t("onboarding.permissions.skip.a11y"))
            .accessibilityHint(lang.t("onboarding.permissions.skip.hint"))
        }
        .onAppear { checkExistingStatus() }
        // Settings alert — shown when a permission has already been denied
        .alert(lang.t("onboarding.permissions.denied.title"), isPresented: $showSettingsAlert) {
            Button(lang.t("onboarding.permissions.denied.open")) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(lang.t("onboarding.permissions.denied.skip"), role: .cancel) { onContinue() }
        } message: {
            Text(lang.t("onboarding.permissions.denied.message"))
        }
    }

    // MARK: - Permission card

    private func permissionCard(
        icon: String, iconColor: Color,
        title: String, description: String,
        granted: Bool
    ) -> some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 12)
                .fill(iconColor)
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.onSurface)
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.onSurface.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundColor(granted ? .green : .onSurface.opacity(0.2))
        }
        .padding(16)
        .background(Color.surfaceVariant.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18)
            .strokeBorder(granted ? Color.green.opacity(0.3) : Color.white.opacity(0.06)))
    }

    // MARK: - Logic

    private func requestAll() {
        // If already all granted, just advance
        if allGranted {
            onContinue()
            return
        }

        // Check for previously denied permissions — the OS won't show a dialog again.
        // Instead, guide the user to Settings.
        let micStatus    = AVAudioApplication.shared.recordPermission
        let photosStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        let micDenied    = micStatus == .denied
        let photosDenied = photosStatus == .denied

        if micDenied || photosDenied {
            showSettingsAlert = true
            return
        }

        // Request normally
        isRequesting = true
        Task {
            // Microphone (iOS 17+ async API)
            let micOK = await AVAudioApplication.requestRecordPermission()
            await MainActor.run { micGranted = micOK }

            // Photo library
            let photosResult = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            await MainActor.run {
                photosGranted = photosResult == .authorized || photosResult == .limited
                isRequesting  = false
            }

            // Pause so user sees the checkmarks, then advance
            try? await Task.sleep(for: .seconds(0.8))
            await MainActor.run { onContinue() }
        }
    }

    private func checkExistingStatus() {
        // Microphone (iOS 17+ API)
        switch AVAudioApplication.shared.recordPermission {
        case .granted:  micGranted = true
        default:        micGranted = false
        }

        // Photos
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        photosGranted = status == .authorized || status == .limited
    }
}

#Preview {
    OnboardingPermissionsView(onContinue: {})
        .environmentObject(LanguageManager())
        .preferredColorScheme(.dark)
}
