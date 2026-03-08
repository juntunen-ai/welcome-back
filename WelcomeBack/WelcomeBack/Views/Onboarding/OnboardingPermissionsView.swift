import SwiftUI
import Photos
import Speech

struct OnboardingPermissionsView: View {

    let onContinue: () -> Void

    @State private var micGranted   = false
    @State private var photosGranted = false
    @State private var isRequesting  = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            Image(systemName: "lock.open.fill")
                .font(.system(size: 56))
                .foregroundColor(.accentYellow)
                .padding(.bottom, 24)

            // Title
            Text("A few permissions")
                .font(.system(size: 32, weight: .black))
                .foregroundColor(.onSurface)
                .multilineTextAlignment(.center)
                .padding(.bottom, 10)

            Text("Welcome Back needs access to your\nmicrophone and photos.")
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
                    title: "Microphone",
                    description: "Lets you speak to the app and hear stories from your family.",
                    granted: micGranted
                )
                permissionCard(
                    icon: "photo.on.rectangle",
                    iconColor: .blue,
                    title: "Photo Library",
                    description: "Displays your memory photos in the Memories tab.",
                    granted: photosGranted
                )
            }
            .padding(.horizontal, 24)

            Spacer()

            // Allow button
            Button(action: requestAll) {
                HStack(spacing: 10) {
                    if isRequesting {
                        ProgressView()
                            .tint(.black)
                    }
                    Text(isRequesting ? "Requesting…" : "Allow Access")
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
            .accessibilityLabel("Allow microphone and photo library access")

            Button(action: onContinue) {
                Text("Skip for now")
                    .font(.system(size: 15))
                    .foregroundColor(.onSurface.opacity(0.4))
                    .underline()
            }
            .buttonStyle(.plain)
            .padding(.bottom, 48)
            .accessibilityLabel("Skip permissions and continue")
            .accessibilityHint("You can grant access later in iOS Settings")
        }
        .onAppear { checkExistingStatus() }
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
        isRequesting = true
        Task {
            // Microphone
            let micStatus = await AVAudioApplication.requestRecordPermission()
            micGranted = micStatus

            // Photo library
            let photosStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            photosGranted = photosStatus == .authorized || photosStatus == .limited

            isRequesting = false

            // Short pause so user sees the checkmarks, then advance
            try? await Task.sleep(for: .seconds(0.6))
            onContinue()
        }
    }

    private func checkExistingStatus() {
        // Microphone
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
        .preferredColorScheme(.dark)
}
