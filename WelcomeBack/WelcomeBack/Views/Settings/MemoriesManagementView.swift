import SwiftUI

/// Manage saved memories/stories — accessible from Settings → Memories & Stories.
struct MemoriesManagementView: View {

    @EnvironmentObject private var appVM: AppViewModel
    @EnvironmentObject private var lang: LanguageManager
    @State private var showingAddSheet = false
    @State private var editingMemoryIndex: Int? = nil

    var body: some View {
        ZStack {
            Color.backgroundDark.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    if appVM.userProfile.memories.isEmpty {
                        emptyState
                            .padding(.horizontal, 16)
                            .padding(.top, 40)
                    } else {
                        memoriesList
                            .padding(.horizontal, 16)
                    }

                    addMemoryButton
                        .padding(.horizontal, 16)
                        .padding(.top, 4)

                    Spacer(minLength: 24)
                }
                .padding(.top, 8)
            }
        }
        .navigationTitle(lang.t("memories.management.title"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingAddSheet) {
            MemoryDetailEditView(memoryIndex: nil)
                .environmentObject(appVM)
                .environmentObject(lang)
        }
        .sheet(item: $editingMemoryIndex) { index in
            MemoryDetailEditView(
                memoryIndex: index,
                existingMemory: appVM.userProfile.memories[index]
            )
            .environmentObject(appVM)
            .environmentObject(lang)
        }
    }

    // MARK: - Subviews

    private var memoriesList: some View {
        VStack(spacing: 12) {
            ForEach(Array(appVM.userProfile.memories.enumerated()), id: \.element.id) { index, memory in
                MemoryRowView(memory: memory)
                    .onTapGesture { editingMemoryIndex = index }
            }
        }
    }

    private var addMemoryButton: some View {
        Button { showingAddSheet = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                Text(lang.t("memories.management.add"))
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.backgroundDark)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.accentYellow)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundColor(.onSurface.opacity(0.3))

            VStack(spacing: 6) {
                Text(lang.t("memories.management.empty"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.onSurface)

                Text(lang.t("memories.management.empty.hint"))
                    .font(.system(size: 14))
                    .foregroundColor(.onSurface.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.surfaceVariant.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

// MARK: - Memory Row

struct MemoryRowView: View {

    let memory: Memory

    private var categoryColor: Color {
        switch memory.category {
        case .family:  return Color(red: 0.20, green: 0.40, blue: 0.85)
        case .events:  return Color(red: 0.85, green: 0.45, blue: 0.10)
        case .places:  return Color(red: 0.15, green: 0.60, blue: 0.35)
        case .other:   return Color(red: 0.45, green: 0.35, blue: 0.70)
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // Thumbnail
            ZStack {
                if let ui = PersistenceService.loadImage(imageURL: memory.imageURL) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(categoryColor.opacity(0.3))
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: "book.fill")
                                .font(.system(size: 20))
                                .foregroundColor(categoryColor)
                        )
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(memory.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.onSurface)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(memory.category.rawValue)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(categoryColor)

                    if !memory.date.isEmpty {
                        Text(memory.date)
                            .font(.system(size: 12))
                            .foregroundColor(.onSurface.opacity(0.4))
                    }
                }

                if !memory.description.isEmpty {
                    Text(memory.description)
                        .font(.system(size: 13))
                        .foregroundColor(.onSurface.opacity(0.5))
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.onSurface.opacity(0.3))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.surfaceVariant.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    NavigationStack {
        MemoriesManagementView()
            .environmentObject(AppViewModel())
            .environmentObject(LanguageManager())
    }
}
