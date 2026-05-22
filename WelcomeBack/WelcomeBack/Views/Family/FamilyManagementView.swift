import SwiftUI

/// Edit / manage family members — accessible from Settings → Family Members.
struct FamilyManagementView: View {

    @EnvironmentObject private var appVM: AppViewModel
    @EnvironmentObject private var lang: LanguageManager
    @State private var showingAddSheet = false
    @State private var editingMemberIndex: Int? = nil

    var body: some View {
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
                    }

                    addMemberButton
                        .padding(.horizontal, 16)
                        .padding(.top, 4)

                    Spacer(minLength: 24)
                }
                .padding(.top, 8)
            }
        }
        .navigationTitle(lang.t("family.management.title"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingAddSheet) {
            FamilyMemberDetailView(memberIndex: nil)
                .environmentObject(appVM)
                .environmentObject(lang)
        }
        .sheet(item: $editingMemberIndex) { index in
            FamilyMemberDetailView(
                memberIndex: index,
                existingMember: appVM.userProfile.familyMembers[index]
            )
            .environmentObject(appVM)
            .environmentObject(lang)
        }
    }

    // MARK: - Subviews

    private var familyList: some View {
        VStack(spacing: 12) {
            ForEach(Array(appVM.familyMembers.enumerated()), id: \.element.id) { index, member in
                FamilyMemberRowView(member: member)
                    .onTapGesture { editingMemberIndex = index }
            }
        }
    }

    private var addMemberButton: some View {
        Button { showingAddSheet = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                Text(lang.t("family.add"))
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
            Image(systemName: "person.3")
                .font(.system(size: 48))
                .foregroundColor(.onSurface.opacity(0.3))

            VStack(spacing: 6) {
                Text(lang.t("family.empty"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.onSurface)

                Text(lang.t("family.empty.management.hint"))
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

#Preview {
    NavigationStack {
        FamilyManagementView()
            .environmentObject(AppViewModel())
            .environmentObject(LanguageManager())
    }
}
