import SwiftUI

struct RecordVoiceView: View {

    @EnvironmentObject private var appVM: AppViewModel
    @State private var editingMemberIndex: Int? = nil

    var body: some View {
        ZStack {
            Color.backgroundDark.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    headerCard
                    memberList
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Record Voice")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $editingMemberIndex) { index in
            FamilyMemberDetailView(
                memberIndex: index,
                existingMember: appVM.userProfile.familyMembers[index]
            )
            .environmentObject(appVM)
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "waveform.badge.mic")
                .font(.system(size: 28))
                .foregroundColor(.accentYellow)
                .frame(width: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text("Voice Recordings")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.onSurface)
                Text("Tap a family member to record their voice so Harri hears a familiar voice when they call.")
                    .font(.system(size: 12))
                    .foregroundColor(.onSurface.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(Color.surfaceVariant.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Member list

    private var memberList: some View {
        VStack(spacing: 12) {
            ForEach(Array(appVM.userProfile.familyMembers.enumerated()), id: \.element.id) { index, member in
                RecordVoiceMemberRow(
                    member: member,
                    isRecorded: $appVM.userProfile.familyMembers[index].isVoiceCloned,
                    onTap: { editingMemberIndex = index }
                )
            }
        }
    }
}

// MARK: - Row

struct RecordVoiceMemberRow: View {

    let member: FamilyMember
    @Binding var isRecorded: Bool
    let onTap: () -> Void

    var body: some View {
        Button { onTap() } label: {
            HStack(spacing: 16) {
                // Photo
                Group {
                    if let uiImage = UIImage(named: member.imageURL) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 64, height: 64)
                            .clipped()
                    } else {
                        Color.surfaceVariant
                            .frame(width: 64, height: 64)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.onSurface.opacity(0.4))
                            )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(alignment: .bottomTrailing) {
                    if isRecorded {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .offset(x: 4, y: 4)
                    }
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(member.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.onSurface)

                    Text(member.relationship)
                        .font(.system(size: 13))
                        .foregroundColor(.onSurface.opacity(0.6))

                    Text(isRecorded ? "Voice recorded ✓" : "No recording yet")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isRecorded ? .green : .onSurface.opacity(0.35))
                        .padding(.top, 2)
                }

                Spacer()

                // Record button
                VStack(spacing: 4) {
                    Image(systemName: isRecorded ? "waveform.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(isRecorded ? .accentYellow : .onSurface.opacity(0.4))

                    Text(isRecorded ? "Re-record" : "Record")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.onSurface.opacity(0.4))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.surfaceVariant.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        isRecorded ? Color.accentYellow.opacity(0.3) : Color.white.opacity(0.05)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        RecordVoiceView()
            .environmentObject(AppViewModel())
    }
}
