import SwiftUI

struct PlaybackView: View {

    let member: FamilyMember

    @EnvironmentObject private var appVM: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = PlaybackViewModel()

    var body: some View {
        NavigationStack {
            GeometryReader { screen in
                ZStack {
                    Color.backgroundDark.ignoresSafeArea()

                    VStack(spacing: 0) {
                        // Photo — capped at 38% of screen height so everything fits
                        memberPhoto(screenHeight: screen.size.height)
                            .padding(.top, 8)
                            .padding(.horizontal, 24)

                        // Story text
                        storySection
                            .padding(.top, 20)
                            .padding(.horizontal, 24)

                        Spacer(minLength: 12)

                        // Play button — always fully visible
                        playButton
                            .padding(.bottom, 32)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        viewModel.stopPlayback()
                        dismiss()
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.onSurface)
                            .frame(width: 44, height: 44)
                            .background(Color.surfaceVariant)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .task {
            await viewModel.loadStory(for: member, userName: appVM.userName)
        }
        .onDisappear {
            viewModel.stopPlayback()
        }
    }

    // MARK: - Subviews

    private func memberPhoto(screenHeight: CGFloat) -> some View {
        let photoHeight = screenHeight * 0.38

        return Group {
            if let uiImage = UIImage(named: member.imageURL) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [Color.surfaceVariant, Color.surface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Text(member.name.prefix(1))
                        .font(.system(size: 80, weight: .black))
                        .foregroundColor(.onSurface.opacity(0.15))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: photoHeight)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .overlay(
            RoundedRectangle(cornerRadius: 32)
                .strokeBorder(Color.surfaceVariant, lineWidth: 3)
        )
        .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
    }

    private var storySection: some View {
        VStack(spacing: 10) {
            Text("Listen to \(member.name), your \(member.relationship.lowercased()), about who you are, \(appVM.userName).")
                .font(.system(size: 22, weight: .black))
                .foregroundColor(.onSurface)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Group {
                if viewModel.isLoading {
                    VStack(spacing: 8) {
                        ProgressView().tint(.accentYellow)
                        Text("Preparing a message…")
                            .font(.system(size: 13))
                            .foregroundColor(.onSurface.opacity(0.6))
                    }
                    .frame(height: 60)
                } else if let error = viewModel.errorMessage {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.accentYellow)
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(.onSurface.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .background(Color.accentYellow.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    Text("\"\(viewModel.story)\"")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.onSurface.opacity(0.8))
                        .italic()
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(18)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    private var playButton: some View {
        VStack(spacing: 12) {
            Button(action: viewModel.togglePlayback) {
                ZStack {
                    Circle()
                        .fill(viewModel.isLoading ? Color.surfaceVariant : Color.accentYellow)
                        .frame(width: 96, height: 96)
                        .shadow(
                            color: viewModel.isLoading ? .clear : Color.accentYellow.opacity(0.4),
                            radius: 16, y: 6
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(Color.accentYellow.opacity(0.2), lineWidth: 6)
                                .scaleEffect(viewModel.isPlaying ? 1.25 : 1.0)
                                .animation(
                                    viewModel.isPlaying
                                        ? .easeInOut(duration: 1).repeatForever(autoreverses: true)
                                        : .default,
                                    value: viewModel.isPlaying
                                )
                        )

                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 40))
                        .foregroundColor(viewModel.isLoading ? .onSurface.opacity(0.3) : .black)
                }
            }
            .disabled(viewModel.isLoading)

            Text(viewModel.isLoading ? "LOADING…" : viewModel.isPlaying ? "NOW PLAYING" : "TAP TO LISTEN")
                .font(.system(size: 13, weight: .bold))
                .tracking(4)
                .foregroundColor(.onSurface.opacity(0.5))
                .animation(.default, value: viewModel.isLoading)
        }
    }
}

#Preview {
    PlaybackView(member: FamilyMember(
        id: "preview-1",
        name: "Anna",
        relationship: "Wife",
        biography: "Anna is the heart of our family.",
        memory1: "Our first date was a walk along the river.",
        memory2: "Every summer we spend a week at the cottage.",
        imageURL: "",
        isVoiceCloned: false
    ))
    .environmentObject(AppViewModel())
}
