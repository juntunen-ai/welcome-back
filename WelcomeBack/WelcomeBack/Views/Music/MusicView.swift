import SwiftUI

struct MusicView: View {

    @EnvironmentObject private var appVM: AppViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundDark.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        aiRadioCard
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                        connectedServicesSection
                            .padding(.horizontal, 16)

                        memoryMixesSection
                            .padding(.horizontal, 16)

                        Spacer(minLength: 24)
                    }
                }
            }
            .navigationTitle("Therapeutic Music")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // Add playlist action (future)
                    } label: {
                        Image(systemName: "text.badge.plus")
                            .foregroundColor(.onSurface)
                            .frame(width: 44, height: 44)
                            .background(Color.surfaceVariant)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    private var aiRadioCard: some View {
        VStack(spacing: 16) {
            Circle()
                .fill(Color.accentYellow)
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: "wand.and.stars.inverse")
                        .font(.system(size: 28))
                        .foregroundColor(.black)
                )

            VStack(spacing: 6) {
                Text("AI Radio")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.onSurface)

                Text("Generating a playlist of your favourite hits from the 1960s to help trigger positive memories.")
                    .font(.system(size: 14))
                    .foregroundColor(.onSurface.opacity(0.6))
                    .multilineTextAlignment(.center)
            }

            Button {
                // Start therapy session (future)
            } label: {
                Label("Start Therapy Session", systemImage: "play.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.accentYellow)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(24)
        .background(Color.accentYellow.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(Color.accentYellow.opacity(0.2))
        )
    }

    private var connectedServicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Connected Services")

            VStack(spacing: 12) {
                MusicServiceRowView(
                    icon: "music.note",
                    title: "Spotify",
                    subtitle: "Connected as Harri J.",
                    color: Color(red: 0.11, green: 0.73, blue: 0.33),
                    isConnected: true
                )
                MusicServiceRowView(
                    icon: "music.note.list",
                    title: "Apple Music",
                    subtitle: "Link your account",
                    color: Color(red: 0.99, green: 0.24, blue: 0.27),
                    isConnected: false
                )
                MusicServiceRowView(
                    icon: "play.rectangle.fill",
                    title: "YouTube Music",
                    subtitle: "Link your account",
                    color: Color(red: 1.0, green: 0.0, blue: 0.0),
                    isConnected: false
                )
            }
        }
    }

    private var memoryMixesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Memory Mixes")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MemoryMixCard(
                    icon: "drop.fill",
                    iconColor: .blue,
                    title: "Summer Lake 1965",
                    trackCount: 12
                )
                MemoryMixCard(
                    icon: "birthday.cake.fill",
                    iconColor: .orange,
                    title: "Birthday Jams",
                    trackCount: 8
                )
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(2)
            .foregroundColor(.onSurface.opacity(0.4))
            .padding(.horizontal, 4)
    }
}

// MARK: - Music Service Row

struct MusicServiceRowView: View {

    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let isConnected: Bool

    var body: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 16)
                .fill(color)
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: icon)
                        .foregroundColor(.white)
                        .font(.system(size: 20))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.onSurface)

                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isConnected ? .accentYellow : .onSurface.opacity(0.5))
            }

            Spacer()

            Button {
                // Settings / Link action (future)
            } label: {
                Text(isConnected ? "Settings" : "Link")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isConnected ? .onSurface.opacity(0.4) : .onSurface)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(isConnected ? Color.surfaceVariant : Color.onSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(16)
        .background(Color.surfaceVariant.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Memory Mix Card

struct MemoryMixCard: View {

    let icon: String
    let iconColor: Color
    let title: String
    let trackCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 16)
                .fill(iconColor.opacity(0.2))
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 36))
                        .foregroundColor(iconColor)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.onSurface)

                Text("\(trackCount) tracks")
                    .font(.system(size: 12))
                    .foregroundColor(.onSurface.opacity(0.5))
            }
        }
        .padding(16)
        .background(Color.surfaceVariant.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.white.opacity(0.05))
        )
    }
}

#Preview {
    MusicView()
        .environmentObject(AppViewModel())
}
