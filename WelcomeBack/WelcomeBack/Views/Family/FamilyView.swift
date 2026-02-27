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
                            familyList
                                .padding(.horizontal, 16)

                            discoveryCard
                                .padding(.horizontal, 16)
                        }

                        Spacer(minLength: 24)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Family")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // Add family member (future)
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.onSurface)
                            .frame(width: 44, height: 44)
                            .background(Color.surfaceVariant)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .sheet(isPresented: $appVM.playbackSheetPresented, onDismiss: {
            appVM.selectedFamilyMember = nil
        }) {
            if let member = appVM.selectedFamilyMember {
                PlaybackView(member: member)
                    .environmentObject(appVM)
            }
        }
    }

    // MARK: - Subviews

    private var familyList: some View {
        VStack(spacing: 12) {
            ForEach(appVM.familyMembers) { member in
                FamilyMemberRowView(member: member)
                    .onTapGesture {
                        appVM.selectFamilyMember(member)
                    }
            }
        }
    }

    private var discoveryCard: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 28))
                .foregroundColor(.accentYellow)

            VStack(alignment: .leading, spacing: 4) {
                Text("New Photos Found")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.accentYellow)

                Text("We've identified new photos of your family members. Would you like to add them to your memories?")
                    .font(.system(size: 14))
                    .foregroundColor(.onSurface.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .background(Color.accentYellow.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.accentYellow.opacity(0.2))
        )
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

                Text("Tap + to add your first family member")
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

// MARK: - Family Member Row

struct FamilyMemberRowView: View {

    let member: FamilyMember

    var body: some View {
        HStack(spacing: 16) {
            // Photo — top-aligned fill so faces show at the right position
            Group {
                if let uiImage = UIImage(named: member.imageURL) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipped()
                } else {
                    Color.surfaceVariant
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.onSurface.opacity(0.3))
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))

            // Info
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

#Preview {
    FamilyView()
        .environmentObject(AppViewModel())
}
