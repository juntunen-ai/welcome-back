import SwiftUI

struct FamilyView: View {

    @EnvironmentObject private var appVM: AppViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundDark.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        if appVM.familyMembers.isEmpty {
                            emptyState
                                .padding(.horizontal, 16)
                                .padding(.top, 40)
                        } else {
                            ForEach(appVM.familyMembers) { member in
                                NavigationLink(destination: FamilyMemberProfileView(member: member)) {
                                    FamilyAlbumCard(member: member)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 16)
                        }
                        Spacer(minLength: 24)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Family")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3")
                .font(.system(size: 48))
                .foregroundColor(.onSurface.opacity(0.3))

            VStack(spacing: 6) {
                Text("No family members yet")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.onSurface)

                Text("Add family members in Settings")
                    .font(.system(size: 14))
                    .foregroundColor(.onSurface.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.surfaceVariant.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

// MARK: - Family Album Card

struct FamilyAlbumCard: View {

    let member: FamilyMember

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            heroImage
                .frame(height: 200)
                .clipped()

            VStack(alignment: .leading, spacing: 6) {
                Text(member.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.onSurface)

                Text(member.relationship.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.accentYellow)

                if !member.biography.isEmpty {
                    Text(member.biography)
                        .font(.system(size: 14))
                        .foregroundColor(.onSurface.opacity(0.65))
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }
            .padding(16)
        }
        .background(Color.surfaceVariant.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(Color.white.opacity(0.05))
        )
    }

    @ViewBuilder
    private var heroImage: some View {
        if let ui = PersistenceService.loadImage(imageURL: member.imageURL) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
        } else {
            PersonAvatarPlaceholder(name: member.name, fontSize: 72)
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Row view (used by FamilyManagementView)

struct FamilyMemberRowView: View {

    let member: FamilyMember

    var body: some View {
        HStack(spacing: 16) {
            MemberImageView(imageURL: member.imageURL, name: member.name, size: 80, cornerRadius: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(member.name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.onSurface)

                Text(member.relationship)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.onSurface.opacity(0.6))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.accentYellow)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color.surfaceVariant.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Shared helpers

extension Int: @retroactive Identifiable {
    public var id: Int { self }
}

// MARK: - Person Avatar Placeholder
// Used by FamilyView, FamilyMemberProfileView, and any view that
// needs a coloured initials avatar when no profile photo is available.

struct PersonAvatarPlaceholder: View {

    let name: String
    var fontSize: CGFloat = 72

    private var initials: String {
        let parts = name.split(separator: " ").map { String($0.prefix(1)) }
        if parts.count >= 2 {
            return (parts[0] + parts[1]).uppercased()
        }
        return String(name.prefix(1)).uppercased()
    }

    private var gradientColors: [Color] {
        // Deterministic palette selection from the name string
        let hash = abs(name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) })
        let palettes: [[Color]] = [
            [Color(red: 0.20, green: 0.40, blue: 0.85), Color(red: 0.08, green: 0.20, blue: 0.60)], // blue
            [Color(red: 0.75, green: 0.25, blue: 0.45), Color(red: 0.50, green: 0.10, blue: 0.30)], // rose
            [Color(red: 0.15, green: 0.55, blue: 0.35), Color(red: 0.05, green: 0.35, blue: 0.20)], // green
            [Color(red: 0.72, green: 0.40, blue: 0.10), Color(red: 0.45, green: 0.22, blue: 0.05)], // amber
            [Color(red: 0.45, green: 0.25, blue: 0.75), Color(red: 0.25, green: 0.12, blue: 0.50)], // purple
            [Color(red: 0.12, green: 0.50, blue: 0.60), Color(red: 0.05, green: 0.30, blue: 0.45)], // teal
        ]
        return palettes[hash % palettes.count]
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(initials)
                .font(.system(size: fontSize, weight: .bold))
                .foregroundColor(.white.opacity(0.92))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    FamilyView()
        .environmentObject(AppViewModel())
}
