import SwiftUI

struct HomeView: View {

    @EnvironmentObject private var appVM: AppViewModel

    @State private var pulseScale1: CGFloat = 1.0
    @State private var pulseScale2: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.backgroundDark.ignoresSafeArea()

            VStack(spacing: 0) {
                heroSection
                    .padding(.top, 24)

                Spacer(minLength: 16)

                micButton

                Spacer(minLength: 16)

                hintCard
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
            .padding(.top, 8)
        }
        .onAppear { startPulse() }
        .sheet(isPresented: $appVM.listeningSheetPresented) {
            ListeningView()
                .environmentObject(appVM)
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

    private var heroSection: some View {
        VStack(spacing: 16) {
            // Profile photo — falls back to initials if image not yet added
            Group {
                if let uiImage = UIImage(named: "user_harri") {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.surfaceVariant
                        .overlay(
                            Text(appVM.userName.prefix(1))
                                .font(.system(size: 36, weight: .black))
                                .foregroundColor(.onSurface.opacity(0.5))
                        )
                }
            }
            .frame(width: 96, height: 96)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Color.accentYellow, lineWidth: 3))
            .shadow(color: Color.accentYellow.opacity(0.3), radius: 12, y: 4)

            VStack(spacing: 4) {
                Text("Welcome Back, \(appVM.userName)!")
                    .font(.system(size: 32, weight: .black))
                    .foregroundColor(.onSurface)

                Text("Remember who you are.")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.onSurface.opacity(0.7))
            }
        }
    }

    private var micButton: some View {
        ZStack {
            Circle()
                .fill(Color.accentYellow.opacity(0.1))
                .frame(width: 288, height: 288)
                .scaleEffect(pulseScale1)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulseScale1)

            Circle()
                .fill(Color.accentYellow.opacity(0.2))
                .frame(width: 240, height: 240)
                .scaleEffect(pulseScale2)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true).delay(1), value: pulseScale2)

            Button(action: appVM.startListening) {
                ZStack {
                    Circle()
                        .fill(Color.accentYellow)
                        .frame(width: 192, height: 192)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.surface, lineWidth: 12)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 20, y: 8)

                    Image(systemName: "mic.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.black)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var hintCard: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color.accentYellow.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "lightbulb")
                        .foregroundColor(.accentYellow)
                )

            Text("Say something like \"Tell me about my wedding day\" or \"Who is Anna?\"")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.onSurface.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .background(Color.surfaceVariant.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.white.opacity(0.05))
        )
    }

    // MARK: - Animation

    private func startPulse() {
        pulseScale1 = 1.08
        pulseScale2 = 1.08
    }
}

#Preview {
    HomeView()
        .environmentObject(AppViewModel())
}
