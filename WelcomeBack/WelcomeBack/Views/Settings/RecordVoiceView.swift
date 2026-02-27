import SwiftUI

struct RecordVoiceView: View {

    @EnvironmentObject private var appVM: AppViewModel

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
                    isRecorded: $appVM.userProfile.familyMembers[index].isVoiceCloned
                )
            }
        }
    }
}

// MARK: - Row

struct RecordVoiceMemberRow: View {

    let member: FamilyMember
    @Binding var isRecorded: Bool
    @State private var showingRecordSheet = false

    var body: some View {
        Button { showingRecordSheet = true } label: {
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
        .sheet(isPresented: $showingRecordSheet) {
            RecordVoiceSheetView(memberName: member.name, isRecorded: $isRecorded)
        }
    }
}

// MARK: - Record sheet (placeholder)

struct RecordVoiceSheetView: View {

    let memberName: String
    @Binding var isRecorded: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var isSimulatingRecord = false
    @State private var progress: Double = 0
    private let recordDuration: Double = 5

    var body: some View {
        ZStack {
            Color.backgroundDark.ignoresSafeArea()

            VStack(spacing: 32) {
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)

                Text("Record \(memberName)'s Voice")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.onSurface)

                Text("Ask \(memberName) to read the phrase below clearly into the microphone.")
                    .font(.system(size: 14))
                    .foregroundColor(.onSurface.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                // Prompt card
                Text("\"Hi \(memberName.components(separatedBy: " ").first ?? memberName), I love you and I'm always here for you.\"")
                    .font(.system(size: 17, weight: .medium, design: .serif))
                    .foregroundColor(.onSurface)
                    .multilineTextAlignment(.center)
                    .padding(20)
                    .background(Color.surfaceVariant.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 24)

                // Mic visualiser
                ZStack {
                    Circle()
                        .fill(isSimulatingRecord ? Color.red.opacity(0.15) : Color.surfaceVariant.opacity(0.3))
                        .frame(width: 110, height: 110)
                        .scaleEffect(isSimulatingRecord ? 1.15 : 1.0)
                        .animation(isSimulatingRecord
                            ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true)
                            : .default, value: isSimulatingRecord)

                    Circle()
                        .fill(isSimulatingRecord ? Color.red : Color.surfaceVariant.opacity(0.6))
                        .frame(width: 80, height: 80)

                    Image(systemName: isSimulatingRecord ? "stop.fill" : "mic.fill")
                        .font(.system(size: 30))
                        .foregroundColor(isSimulatingRecord ? .white : .accentYellow)
                }

                if isSimulatingRecord {
                    ProgressView(value: progress)
                        .tint(.accentYellow)
                        .padding(.horizontal, 48)
                }

                Button {
                    if isSimulatingRecord {
                        // Stop early — mark as recorded
                        isSimulatingRecord = false
                        isRecorded = true
                        dismiss()
                    } else {
                        startRecording()
                    }
                } label: {
                    Text(isSimulatingRecord ? "Stop Recording" : "Start Recording")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(isSimulatingRecord ? .white : .backgroundDark)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isSimulatingRecord ? Color.red : Color.accentYellow)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 24)
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    private func startRecording() {
        isSimulatingRecord = true
        progress = 0

        // Simulate recording progress
        let step = 0.05
        Timer.scheduledTimer(withTimeInterval: recordDuration * step, repeats: true) { timer in
            progress += step
            if progress >= 1.0 {
                timer.invalidate()
                isSimulatingRecord = false
                isRecorded = true
                dismiss()
            }
        }
    }
}

#Preview {
    NavigationStack {
        RecordVoiceView()
            .environmentObject(AppViewModel())
    }
}
