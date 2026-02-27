import SwiftUI
import PhotosUI

/// Shared detail / edit form for a family member.
/// • Edit mode  — pass the index into `appVM.userProfile.familyMembers`
/// • Add mode   — pass `nil`; a new member is appended on Save
struct FamilyMemberDetailView: View {

    @EnvironmentObject private var appVM: AppViewModel
    @Environment(\.dismiss) private var dismiss

    /// `nil` → add-new mode.  Non-nil → edit existing member at this index.
    let memberIndex: Int?

    // Local draft — committed on Save
    @State private var draft: FamilyMember

    // Photo picker
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoImage: Image?

    // MARK: - Init

    init(memberIndex: Int?, existingMember: FamilyMember? = nil) {
        self.memberIndex = memberIndex
        let blank = FamilyMember(
            id: UUID().uuidString,
            name: "",
            relationship: "",
            phone: "",
            biography: "",
            memory1: "",
            memory2: "",
            imageURL: "",
            isVoiceCloned: false
        )
        _draft = State(initialValue: existingMember ?? blank)
    }

    var isAddMode: Bool { memberIndex == nil }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundDark.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        photoSection
                        basicSection
                        biographySection
                        memoriesSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(isAddMode ? "Add Family Member" : draft.name)
            .navigationBarTitleDisplayMode(.large)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.onSurface.opacity(0.6))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(draft.name.isEmpty ? .onSurface.opacity(0.3) : .accentYellow)
                        .disabled(draft.name.isEmpty)
                }
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let ui = UIImage(data: data) {
                        photoImage = Image(uiImage: ui)
                    }
                }
            }
        }
    }

    // MARK: - Photo section

    private var photoSection: some View {
        VStack(spacing: 12) {
            // Preview
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.surfaceVariant.opacity(0.5))
                    .frame(width: 120, height: 120)

                if let photoImage {
                    photoImage
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                } else if let ui = UIImage(named: draft.imageURL) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.onSurface.opacity(0.25))
                }
            }

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label("Choose Photo", systemImage: "photo.on.rectangle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.accentYellow)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.surfaceVariant.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Basic info

    private var basicSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("About")

            VStack(spacing: 0) {
                formField(icon: "person.fill",        iconColor: .blue,
                          label: "Name",             placeholder: "Full name",
                          binding: $draft.name)
                divider
                formField(icon: "heart.fill",         iconColor: .pink,
                          label: "Relationship",     placeholder: "e.g. Daughter, Son, Wife",
                          binding: $draft.relationship)
                divider
                formField(icon: "phone.fill",         iconColor: .green,
                          label: "Phone",            placeholder: "+358 …",
                          binding: $draft.phone,
                          keyboardType: .phonePad)
            }
            .background(Color.surfaceVariant.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Biography

    private var biographySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("Biography")

            HStack(alignment: .top, spacing: 14) {
                iconBadge("text.quote", color: .purple)
                    .padding(.top, 2)

                TextField("A few words about this person…",
                          text: $draft.biography, axis: .vertical)
                    .font(.system(size: 15))
                    .foregroundColor(.onSurface)
                    .lineLimit(4, reservesSpace: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.surfaceVariant.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Memories

    private var memoriesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("Shared Memories")

            VStack(spacing: 0) {
                memoryField(icon: "star.fill",  iconColor: .accentYellow,
                            label: "Memory 1",  placeholder: "A special moment together…",
                            binding: $draft.memory1)
                divider
                memoryField(icon: "star.fill",  iconColor: Color(red: 1, green: 0.6, blue: 0),
                            label: "Memory 2",  placeholder: "Another cherished memory…",
                            binding: $draft.memory2)
            }
            .background(Color.surfaceVariant.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Row helpers

    private func formField(icon: String, iconColor: Color,
                           label: String, placeholder: String,
                           binding: Binding<String>,
                           keyboardType: UIKeyboardType = .default) -> some View {
        HStack(spacing: 14) {
            iconBadge(icon, color: iconColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.onSurface.opacity(0.45))
                    .textCase(.uppercase)
                    .tracking(0.6)

                TextField(placeholder, text: binding)
                    .font(.system(size: 15))
                    .foregroundColor(.onSurface)
                    .keyboardType(keyboardType)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func memoryField(icon: String, iconColor: Color,
                             label: String, placeholder: String,
                             binding: Binding<String>) -> some View {
        HStack(alignment: .top, spacing: 14) {
            iconBadge(icon, color: iconColor)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.onSurface.opacity(0.45))
                    .textCase(.uppercase)
                    .tracking(0.6)

                TextField(placeholder, text: binding, axis: .vertical)
                    .font(.system(size: 15))
                    .foregroundColor(.onSurface)
                    .lineLimit(3, reservesSpace: false)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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

    // MARK: - Save

    private func save() {
        if let index = memberIndex {
            appVM.userProfile.familyMembers[index] = draft
        } else {
            appVM.userProfile.familyMembers.append(draft)
        }
        dismiss()
    }
}

#Preview {
    FamilyMemberDetailView(memberIndex: nil)
        .environmentObject(AppViewModel())
}
