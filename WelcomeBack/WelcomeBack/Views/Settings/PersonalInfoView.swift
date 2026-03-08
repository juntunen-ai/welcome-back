import SwiftUI
import PhotosUI

struct PersonalInfoView: View {

    @EnvironmentObject private var appVM: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var editingMemberIndex: Int? = nil
    @State private var photoPickerItem: PhotosPickerItem? = nil

    var body: some View {
        ZStack {
            Color.backgroundDark.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    profilePhotoSection
                    infoSection
                    familySection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Personal Info")
        .navigationBarTitleDisplayMode(.large)
        .scrollDismissesKeyboard(.interactively)
        .sheet(item: $editingMemberIndex) { index in
            FamilyMemberDetailView(
                memberIndex: index,
                existingMember: appVM.userProfile.familyMembers[index]
            )
            .environmentObject(appVM)
        }
        .onChange(of: photoPickerItem) { _, newItem in
            Task {
                guard let newItem,
                      let data = try? await newItem.loadTransferable(type: Data.self),
                      let uiImage = UIImage(data: data) else { return }
                let url = PersistenceService.savePhoto(uiImage, memberID: "user_profile")
                appVM.userProfile.profileImageURL = url
            }
        }
    }

    // MARK: - Profile photo section

    private var profilePhotoSection: some View {
        VStack(spacing: 12) {
            sectionHeader("Your Photo")

            HStack(spacing: 20) {
                // Current photo / avatar
                Group {
                    if let uiImage = PersistenceService.loadImage(imageURL: appVM.userProfile.profileImageURL) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        PersonAvatarPlaceholder(name: appVM.userProfile.name, fontSize: 36)
                    }
                }
                .frame(width: 90, height: 90)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Color.accentYellow, lineWidth: 2.5))
                .shadow(color: Color.accentYellow.opacity(0.3), radius: 8, y: 3)

                // Picker button
                PhotosPicker(selection: $photoPickerItem,
                             matching: .images,
                             photoLibrary: .shared()) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Change Photo")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.accentYellow)
                        Text("Tap to choose from your photo library")
                            .font(.system(size: 12))
                            .foregroundColor(.onSurface.opacity(0.5))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(16)
            .background(Color.surfaceVariant.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Sections

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("About You")

            VStack(spacing: 0) {
                infoField(icon: "person.fill",        iconColor: .blue,
                          label: "Name",
                          binding: $appVM.userProfile.name)
                divider
                infoField(icon: "house.fill",         iconColor: .orange,
                          label: "Address",
                          binding: $appVM.userProfile.address)
                divider
                infoField(icon: "mappin.circle.fill",  iconColor: .red,
                          label: "Current Location",
                          binding: $appVM.userProfile.currentLocation)
                divider
                bioField
            }
            .background(Color.surfaceVariant.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var familySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("Family Members")

            VStack(spacing: 0) {
                ForEach(Array(appVM.userProfile.familyMembers.enumerated()), id: \.element.id) { index, member in
                    familyRow(index: index, member: member)
                    if index < appVM.userProfile.familyMembers.count - 1 {
                        divider
                    }
                }
            }
            .background(Color.surfaceVariant.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Row helpers

    private func infoField(icon: String, iconColor: Color, label: String,
                           binding: Binding<String>) -> some View {
        HStack(spacing: 14) {
            iconBadge(icon, color: iconColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.onSurface.opacity(0.45))
                    .textCase(.uppercase)
                    .tracking(0.6)

                TextField("—", text: binding)
                    .font(.system(size: 15))
                    .foregroundColor(.onSurface)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var bioField: some View {
        HStack(alignment: .top, spacing: 14) {
            iconBadge("text.quote", color: .purple)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text("Biography")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.onSurface.opacity(0.45))
                    .textCase(.uppercase)
                    .tracking(0.6)

                TextField("A few words about yourself…", text: $appVM.userProfile.biography, axis: .vertical)
                    .font(.system(size: 15))
                    .foregroundColor(.onSurface)
                    .lineLimit(4, reservesSpace: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func familyRow(index: Int, member: FamilyMember) -> some View {
        Button { editingMemberIndex = index } label: {
            HStack(spacing: 14) {
                MemberImageView(imageURL: member.imageURL, name: member.name, size: 36, cornerRadius: 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(member.name.isEmpty ? "Unnamed" : member.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.onSurface)
                    Text(member.relationship.isEmpty ? "Relationship" : member.relationship)
                        .font(.system(size: 12))
                        .foregroundColor(.onSurface.opacity(0.55))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.onSurface.opacity(0.2))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Utility

    private func iconBadge(_ name: String, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(color)
            .frame(width: 30, height: 30)
            .overlay(
                Image(systemName: name)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            )
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .foregroundColor(.accentYellow)
            .font(.system(size: 12, weight: .bold))
            .tracking(1.5)
            .textCase(.uppercase)
            .padding(.leading, 4)
            .padding(.bottom, 4)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 1)
            .padding(.leading, 60)
    }
}

#Preview {
    NavigationStack {
        PersonalInfoView()
            .environmentObject(AppViewModel())
    }
}
