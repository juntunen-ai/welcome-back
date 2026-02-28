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
            Color.surfaceVariant
                .frame(maxWidth: .infinity)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.onSurface.opacity(0.2))
                )
        }
    }
}

// MARK: - Row view (used by FamilyManagementView)

struct FamilyMemberRowView: View {

    let member: FamilyMember

    var body: some View {
        HStack(spacing: 16) {
            MemberImageView(imageURL: member.imageURL, size: 80, cornerRadius: 20)

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

#Preview {
    FamilyView()
        .environmentObject(AppViewModel())
}
