import SwiftUI
import PhotosUI

/// Onboarding step: let the user add their own profile photo.
struct OnboardingPhotoView: View {

    let onContinue: () -> Void

    @EnvironmentObject private var appVM: AppViewModel
    @EnvironmentObject private var lang: LanguageManager
    @State private var photoPickerItem: PhotosPickerItem? = nil
    @State private var profileImage: UIImage? = nil
    @State private var isLoadingPhoto = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Photo picker circle
            PhotosPicker(selection: $photoPickerItem, matching: .images) {
                ZStack {
                    Circle()
                        .fill(Color.surfaceVariant)

                    if let img = profileImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 52))
                            .foregroundColor(.onSurface.opacity(0.35))
                    }

                    if isLoadingPhoto {
                        Color.black.opacity(0.45)
                        ProgressView().tint(.accentYellow).scaleEffect(1.2)
                    }
                }
                .frame(width: 160, height: 160)
                .clipShape(Circle())
                .overlay(
                    Circle().strokeBorder(
                        profileImage != nil ? Color.accentYellow : Color.white.opacity(0.15),
                        lineWidth: 3)
                )
                .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
            }
            .onChange(of: photoPickerItem) { _, item in
                Task {
                    isLoadingPhoto = true
                    if let data = try? await item?.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        profileImage = img
                    }
                    isLoadingPhoto = false
                }
            }

            Text(lang.t("onboarding.photo.tap"))
                .font(.system(size: 14))
                .foregroundColor(.onSurface.opacity(0.4))
                .padding(.top, 14)

            Spacer(minLength: 36)

            // Title + subtitle
            VStack(spacing: 10) {
                Text(lang.t("onboarding.photo.title"))
                    .font(.system(size: 32, weight: .black))
                    .foregroundColor(.onSurface)
                    .multilineTextAlignment(.center)

                Text(lang.t("onboarding.photo.subtitle"))
                    .font(.system(size: 16))
                    .foregroundColor(.onSurface.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }

            Spacer()

            // Buttons
            VStack(spacing: 14) {
                Button(action: saveAndContinue) {
                    Text(lang.t("onboarding.photo.continue"))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.accentYellow)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button(action: onContinue) {
                    Text(lang.t("onboarding.photo.skip"))
                        .font(.system(size: 15))
                        .foregroundColor(.onSurface.opacity(0.5))
                        .underline()
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    private func saveAndContinue() {
        if let img = profileImage {
            let url = PersistenceService.savePhoto(img, memberID: "user_profile")
            appVM.userProfile.profileImageURL = url
        }
        onContinue()
    }
}

#Preview {
    OnboardingPhotoView(onContinue: {})
        .environmentObject(AppViewModel())
        .environmentObject(LanguageManager())
        .preferredColorScheme(.dark)
}
