import SwiftUI
import PhotosUI

/// Add or edit a Memory/Story — presented as a sheet from MemoriesManagementView.
struct MemoryDetailEditView: View {

    @EnvironmentObject private var appVM: AppViewModel
    @Environment(\.dismiss) private var dismiss

    let memoryIndex: Int?

    @State private var draft: Memory
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoImage: Image?
    @State private var pickedUIImage: UIImage?

    // MARK: - Init

    init(memoryIndex: Int?, existingMemory: Memory? = nil) {
        self.memoryIndex = memoryIndex
        let blank = Memory(
            id: UUID().uuidString,
            title: "",
            date: "",
            imageURL: "",
            category: .family,
            description: ""
        )
        _draft = State(initialValue: existingMemory ?? blank)
    }

    var isAddMode: Bool { memoryIndex == nil }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundDark.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        photoSection
                        titleSection
                        dateSection
                        categorySection
                        descriptionSection
                        deleteSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(isAddMode ? "Add Memory" : draft.title)
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
                        .foregroundColor(draft.title.isEmpty ? .onSurface.opacity(0.3) : .accentYellow)
                        .disabled(draft.title.isEmpty)
                }
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let ui = UIImage(data: data) {
                        pickedUIImage = ui
                        photoImage = Image(uiImage: ui)
                    }
                }
            }
        }
    }

    // MARK: - Photo

    private var photoSection: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.surfaceVariant.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)

                if let photoImage {
                    photoImage
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                } else if let ui = PersistenceService.loadImage(imageURL: draft.imageURL) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                } else {
                    Image(systemName: "book.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.onSurface.opacity(0.25))
                }
            }

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label("Choose Photo", systemImage: "photo.badge.plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.accentYellow)
            }
        }
        .padding(.vertical, 12)
        .background(Color.surfaceVariant.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("Title")

            HStack(spacing: 14) {
                iconBadge("text.badge.star", color: .orange)
                TextField("e.g. Our Wedding Day", text: $draft.title)
                    .font(.system(size: 15))
                    .foregroundColor(.onSurface)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.surfaceVariant.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Date

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("Date")

            HStack(spacing: 14) {
                iconBadge("calendar", color: .blue)
                TextField("e.g. June 14, 1980", text: $draft.date)
                    .font(.system(size: 15))
                    .foregroundColor(.onSurface)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.surfaceVariant.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Category

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("Category")

            HStack(spacing: 14) {
                iconBadge("tag.fill", color: .purple)

                Picker("Category", selection: $draft.category) {
                    ForEach(MemoryCategory.allCases, id: \.self) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.surfaceVariant.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("Story")

            HStack(alignment: .top, spacing: 14) {
                iconBadge("text.quote", color: .green)
                    .padding(.top, 2)
                TextField("Tell the story of this memory…",
                          text: $draft.description, axis: .vertical)
                    .font(.system(size: 15))
                    .foregroundColor(.onSurface)
                    .lineLimit(8, reservesSpace: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.surfaceVariant.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Delete

    @ViewBuilder
    private var deleteSection: some View {
        if !isAddMode {
            Button {
                if let idx = memoryIndex {
                    appVM.userProfile.memories.remove(at: idx)
                }
                dismiss()
            } label: {
                HStack {
                    Spacer()
                    Label("Delete Memory", systemImage: "trash")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(.vertical, 14)
                .background(Color.red.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
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

    // MARK: - Save

    private func save() {
        if let ui = pickedUIImage {
            draft.imageURL = PersistenceService.savePhoto(ui, memberID: "memory_\(draft.id)")
        }

        if let index = memoryIndex {
            appVM.userProfile.memories[index] = draft
        } else {
            appVM.userProfile.memories.append(draft)
        }
        dismiss()
    }
}

#Preview {
    MemoryDetailEditView(memoryIndex: nil)
        .environmentObject(AppViewModel())
}
