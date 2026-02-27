import SwiftUI

struct PlaybackView: View {

    let member: FamilyMember

    @EnvironmentObject private var appVM: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = PlaybackViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundDark.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        memberPhoto
                            .padding(.top, 16)

                        storySection
                            .padding(.top, 40)

                        playButton
                            .padding(.top, 32)

                        Spacer(minLength: 64)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
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

    private var memberPhoto: some View {
        GeometryReader { geo in
            let width = min(geo.size.width, 380)
            let height = width * 1.25

            Group {
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
                            .font(.system(size: 100, weight: .black))
                            .foregroundColor(.onSurface.opacity(0.15))
                    }
                }
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 40))
            .overlay(
                RoundedRectangle(cornerRadius: 40)
                    .strokeBorder(Color.surfaceVariant, lineWidth: 4)
            )
            .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
            .frame(maxWidth: .infinity)
        }
        .aspectRatio(0.8, contentMode: .fit)
    }

    private var storySection: some View {
        VStack(spacing: 16) {
            Text("Listen to \(member.name), your \(member.relationship.lowercased()), about who you are, \(appVM.userName).")
                .font(.system(size: 28, weight: .black))
                .foregroundColor(.onSurface)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Group {
                if viewModel.isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.accentYellow)
                        Text("Preparing a message...")
                            .font(.system(size: 14))
                            .foregroundColor(.onSurface.opacity(0.6))
                    }
                    .frame(height: 80)
                } else if let error = viewModel.errorMessage {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.accentYellow)
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.onSurface.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(20)
                    .background(Color.accentYellow.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    Text("\"\(viewModel.story)\"")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.onSurface.opacity(0.8))
                        .italic()
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(24)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
            }
        }
    }

    private var playButton: some View {
        VStack(spacing: 16) {
            Button(action: viewModel.togglePlayback) {
                ZStack {
                    Circle()
                        .fill(viewModel.isLoading ? Color.surfaceVariant : Color.accentYellow)
                        .frame(width: 128, height: 128)
                        .shadow(
                            color: viewModel.isLoading ? .clear : Color.accentYellow.opacity(0.4),
                            radius: 20, y: 8
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(Color.accentYellow.opacity(0.2), lineWidth: 8)
                                .scaleEffect(viewModel.isPlaying ? 1.2 : 1.0)
                                .animation(
                                    viewModel.isPlaying
                                        ? .easeInOut(duration: 1).repeatForever(autoreverses: true)
                                        : .default,
                                    value: viewModel.isPlaying
                                )
                        )

                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 52))
                        .foregroundColor(viewModel.isLoading ? .onSurface.opacity(0.3) : .black)
                }
            }
            .disabled(viewModel.isLoading)

            Text(viewModel.isLoading ? "LOADING..." : viewModel.isPlaying ? "NOW PLAYING" : "TAP TO LISTEN")
                .font(.system(size: 14, weight: .bold))
                .tracking(4)
                .foregroundColor(.onSurface.opacity(0.5))
                .animation(.default, value: viewModel.isLoading)
        }
    }
}

#Preview {
    PlaybackView(member: FamilyMember.mockData[0])
        .environmentObject(AppViewModel())
}
