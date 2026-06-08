import SwiftUI

struct MemoriesView: View {

    @EnvironmentObject private var appVM: AppViewModel
    @EnvironmentObject private var lang: LanguageManager

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundDark.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        peopleSection
                        placesSection
                        memoriesSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle(lang.t("memories.title"))
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - People

    @ViewBuilder
    private var peopleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(lang.t("memories.people"))

            if appVM.userProfile.familyMembers.isEmpty {
                emptySectionView(icon: "person.3", message: lang.t("memories.people.empty"))
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(appVM.userProfile.familyMembers) { member in
                        NavigationLink(destination: FamilyMemberProfileView(member: member)) {
                            PersonTile(member: member)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Places

    @ViewBuilder
    private var placesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(lang.t("memories.places"))

            if appVM.userProfile.places.isEmpty {
                emptySectionView(icon: "mappin.and.ellipse", message: lang.t("memories.places.empty"))
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(appVM.userProfile.places) { place in
                        NavigationLink(destination: PlaceDetailView(place: place).environmentObject(lang)) {
                            PlaceTile(place: place)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Memories / Stories

    @ViewBuilder
    private var memoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(lang.t("memories.stories"))

            if appVM.userProfile.memories.isEmpty {
                emptySectionView(icon: "book.closed", message: lang.t("memories.stories.empty"))
            } else {
                VStack(spacing: 12) {
                    ForEach(appVM.userProfile.memories) { memory in
                        NavigationLink(destination: MemoryStoryDetailView(memory: memory)) {
                            MemoryStoryCard(memory: memory)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .bold))
            .tracking(1.5)
            .foregroundColor(.accentYellow)
            .padding(.leading, 4)
    }

    private func emptySectionView(icon: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(.onSurface.opacity(0.2))
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.onSurface.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Color.surfaceVariant.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - Person Tile

private struct PersonTile: View {

    let member: FamilyMember

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background — use GeometryReader to contain scaledToFill
            GeometryReader { geo in
                if let ui = PersistenceService.loadImage(imageURL: member.imageURL) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    PersonAvatarPlaceholder(name: member.name, fontSize: 36)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }

            // Gradient scrim
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.8),  location: 0),
                    .init(color: .black.opacity(0.3),  location: 0.5),
                    .init(color: .clear,                location: 0.75),
                ],
                startPoint: .bottom,
                endPoint: .top
            )

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .shadow(color: .black.opacity(0.7), radius: 3, y: 1)

                Text(member.relationship.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.accentYellow)
                    .lineLimit(1)
                    .shadow(color: .black.opacity(0.7), radius: 3, y: 1)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.white.opacity(0.08))
        )
        .accessibilityLabel("\(member.name), \(member.relationship)")
    }
}

// MARK: - Place Tile

private struct PlaceTile: View {

    let place: Place

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background — use GeometryReader to contain scaledToFill
            GeometryReader { geo in
                if let ui = PersistenceService.loadImage(imageURL: place.imageURL) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    ZStack {
                        Color.surfaceVariant
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.onSurface.opacity(0.15))
                    }
                }
            }

            // Gradient scrim
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.8),  location: 0),
                    .init(color: .black.opacity(0.3),  location: 0.5),
                    .init(color: .clear,                location: 0.75),
                ],
                startPoint: .bottom,
                endPoint: .top
            )

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .shadow(color: .black.opacity(0.7), radius: 3, y: 1)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.white.opacity(0.08))
        )
        .accessibilityLabel(place.name)
    }
}

// MARK: - Memory Story Card

/// Displays a Memory with image thumbnail on left, text on right.
struct MemoryStoryCard: View {

    let memory: Memory

    private var categoryColor: Color {
        switch memory.category {
        case .family:  return Color(red: 0.20, green: 0.40, blue: 0.85)
        case .events:  return Color(red: 0.85, green: 0.45, blue: 0.10)
        case .places:  return Color(red: 0.15, green: 0.60, blue: 0.35)
        case .other:   return Color(red: 0.45, green: 0.35, blue: 0.70)
        }
    }

    private var categoryIcon: String {
        switch memory.category {
        case .family:  return "heart.fill"
        case .events:  return "sparkles"
        case .places:  return "map.fill"
        case .other:   return "doc.text.fill"
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // Image thumbnail
            ZStack {
                if let ui = PersistenceService.loadImage(imageURL: memory.imageURL) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(categoryColor.opacity(0.25))
                        .frame(width: 64, height: 64)
                        .overlay(
                            Image(systemName: categoryIcon)
                                .font(.system(size: 24))
                                .foregroundColor(categoryColor)
                        )
                }
            }

            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(memory.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.onSurface)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(memory.category.rawValue)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(categoryColor)

                    if !memory.date.isEmpty {
                        Text(memory.date)
                            .font(.system(size: 11))
                            .foregroundColor(.onSurface.opacity(0.4))
                    }
                }

                if !memory.description.isEmpty {
                    Text(memory.description)
                        .font(.system(size: 12))
                        .foregroundColor(.onSurface.opacity(0.6))
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.surfaceVariant.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.white.opacity(0.06))
        )
        .accessibilityLabel("\(memory.title), \(memory.date)")
    }
}

#Preview {
    MemoriesView()
        .environmentObject(AppViewModel())
        .environmentObject(LanguageManager())
}
