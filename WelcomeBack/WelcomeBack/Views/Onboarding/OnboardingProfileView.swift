import SwiftUI
import PhotosUI

struct OnboardingProfileView: View {

    let onContinue: () -> Void

    @EnvironmentObject private var appVM: AppViewModel
    @State private var name: String = ""
    @State private var photoPickerItem: PhotosPickerItem? = nil
    @State private var profileImage: UIImage? = nil
    @FocusState private var nameFieldFocused: Bool

    private var canContinue: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 12) {
                    Text("What's your name?")
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(.onSurface)
                        .multilineTextAlignment(.center)

                    Text("We'll use this to personalise your experience.")
                        .font(.system(size: 16))
                        .foregroundColor(.onSurface.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .padding(.top, 60)

                // Profile photo picker
                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                    ZStack {
                        if let img = profileImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Color.surfaceVariant
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: 36))
                                .foregroundColor(.onSurface.opacity(0.4))
                        }
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(
                        profileImage != nil ? Color.accentYellow : Color.white.opacity(0.15),
                        lineWidth: 3))
                }
                .accessibilityLabel("Add profile photo (optional)")
                .onChange(of: photoPickerItem) { _, item in
                    Task {
                        if let data = try? await item?.loadTransferable(type: Data.self),
                           let img = UIImage(data: data) {
                            profileImage = img
                        }
                    }
                }

                // Name field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Name")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.onSurface.opacity(0.45))
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .padding(.leading, 4)

                    TextField("e.g. Harri", text: $name)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.onSurface)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color.surfaceVariant.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white.opacity(0.08)))
                        .focused($nameFieldFocused)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                        .submitLabel(.continue)
                        .onSubmit { if canContinue { saveAndContinue() } }
                        .accessibilityLabel("Enter your name")
                }
                .padding(.horizontal, 32)

                Spacer(minLength: 40)

                // Continue button
                Button(action: saveAndContinue) {
                    Text("Continue")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(canContinue ? .black : .onSurface.opacity(0.3))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(canContinue ? Color.accentYellow : Color.surfaceVariant.opacity(0.5))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!canContinue)
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
                .accessibilityLabel("Continue to next step")
                .accessibilityHint(canContinue ? "" : "Enter your name first")
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear { nameFieldFocused = true }
    }

    private func saveAndContinue() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        appVM.userProfile.name = trimmed

        if let img = profileImage {
            let url = PersistenceService.savePhoto(img, memberID: "user_profile")
            // Store in UserProfile — we'll use this as the user's profile photo
            // For now save it; HomeView will load it via PersistenceService
            appVM.userProfile.biography = appVM.userProfile.biography   // trigger save
            _ = url  // saved; HomeView picks it up via PersistenceService
        }

        nameFieldFocused = false
        onContinue()
    }
}

#Preview {
    OnboardingProfileView(onContinue: {})
        .environmentObject(AppViewModel())
        .preferredColorScheme(.dark)
}
