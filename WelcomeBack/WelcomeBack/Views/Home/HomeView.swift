import SwiftUI
import CoreLocation

struct HomeView: View {

    @EnvironmentObject private var appVM: AppViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var locationManager = HomeLocationManager()

    @State private var pulseScale1: CGFloat = 1.0
    @State private var pulseScale2: CGFloat = 1.0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundDark.ignoresSafeArea()

                VStack(spacing: 0) {
                    heroSection
                        .padding(.top, 20)
                        .padding(.horizontal, 24)

                    Spacer(minLength: 16)

                    micButton

                    Spacer(minLength: 16)

                    hintCard
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                }
                .padding(.top, 8)
            }
            .onAppear {
                startPulse()
                locationManager.start()
            }
        }
    }

    // MARK: - Hero section

    /// Profile circle on the left, current location on the right.
    private var heroSection: some View {
        HStack(alignment: .center, spacing: 12) {

            // ── Left: profile photo + greeting ────────────────────────────────
            HStack(alignment: .center, spacing: 12) {
                NavigationLink(destination: PersonalInfoView().environmentObject(appVM)) {
                    profileCircle
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome Back,")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.onSurface.opacity(0.5))

                    Text(appVM.userName.isEmpty ? "Friend" : appVM.userName)
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(.onSurface)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text("Remember who you are.")
                        .font(.system(size: 11))
                        .foregroundColor(.onSurface.opacity(0.4))
                }
            }

            Spacer()

            // ── Right: location ───────────────────────────────────────────────
            locationCard
        }
    }

    private var profileCircle: some View {
        Group {
            if !appVM.userProfile.profileImageURL.isEmpty,
               let uiImage = PersistenceService.loadImage(imageURL: appVM.userProfile.profileImageURL) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.surfaceVariant
                    .overlay(
                        Text(appVM.userName.prefix(1).uppercased())
                            .font(.system(size: 24, weight: .black))
                            .foregroundColor(.onSurface.opacity(0.5))
                    )
            }
        }
        .frame(width: 68, height: 68)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.accentYellow, lineWidth: 2.5))
        .shadow(color: Color.accentYellow.opacity(0.3), radius: 8, y: 3)
        .accessibilityLabel("Your profile photo — tap to edit")
    }

    private var locationCard: some View {
        VStack(alignment: .trailing, spacing: 5) {
            // Label row
            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.accentYellow)
                Text("Your Location")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.accentYellow)
            }

            if locationManager.isLoading {
                Text("Finding location…")
                    .font(.system(size: 12))
                    .foregroundColor(.onSurface.opacity(0.35))
            } else if let city = locationManager.city {
                // City / country
                Text(city)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.onSurface)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)

                // Street address (if available)
                if let street = locationManager.streetAddress {
                    Text(street)
                        .font(.system(size: 12))
                        .foregroundColor(.onSurface.opacity(0.55))
                        .multilineTextAlignment(.trailing)
                        .lineLimit(1)
                }
            } else {
                Text("Location unavailable")
                    .font(.system(size: 12))
                    .foregroundColor(.onSurface.opacity(0.35))
            }
        }
        .frame(maxWidth: 150, alignment: .trailing)
    }

    // MARK: - Mic button

    private var micButton: some View {
        ZStack {
            if !reduceMotion {
                Circle()
                    .fill(Color.accentYellow.opacity(0.1))
                    .frame(width: 288, height: 288)
                    .scaleEffect(pulseScale1)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true),
                               value: pulseScale1)

                Circle()
                    .fill(Color.accentYellow.opacity(0.2))
                    .frame(width: 240, height: 240)
                    .scaleEffect(pulseScale2)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true).delay(1),
                               value: pulseScale2)
            }

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
            .accessibilityLabel("Start listening")
            .accessibilityHint("Double-tap to begin a voice conversation about your memories")
        }
    }

    // MARK: - Hint card

    private var hintCard: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color.accentYellow.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "lightbulb")
                        .foregroundColor(.accentYellow)
                )
                .accessibilityHidden(true)

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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Hint: say something like 'Tell me about my wedding day' or 'Who is Anna'")
    }

    // MARK: - Animation

    private func startPulse() {
        guard !reduceMotion else { return }
        pulseScale1 = 1.08
        pulseScale2 = 1.08
    }
}

// MARK: - Location manager

/// Fetches the device's current location once and reverse-geocodes it to a
/// city + street address for display on the Home screen.
@MainActor
final class HomeLocationManager: NSObject, ObservableObject {

    @Published var city: String?
    @Published var streetAddress: String?
    @Published var isLoading = true

    private let clManager = CLLocationManager()
    private var geocoded = false

    override init() {
        super.init()
        clManager.delegate = self
        clManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func start() {
        switch clManager.authorizationStatus {
        case .notDetermined:
            clManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            clManager.requestLocation()
        default:
            isLoading = false
        }
    }

    private func geocode(_ location: CLLocation) async {
        guard !geocoded else { return }
        geocoded = true
        do {
            if let p = try await CLGeocoder().reverseGeocodeLocation(location).first {
                let parts = [p.locality, p.country].compactMap { $0 }
                city = parts.isEmpty ? p.administrativeArea : parts.joined(separator: ", ")
                if let street = p.thoroughfare {
                    let num = p.subThoroughfare.map { "\($0) " } ?? ""
                    streetAddress = num + street
                } else {
                    streetAddress = p.administrativeArea
                }
            }
        } catch {}
        isLoading = false
    }
}

extension HomeLocationManager: CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else { return }
        manager.stopUpdatingLocation()
        Task { @MainActor [weak self] in
            await self?.geocode(loc)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.isLoading = false
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                clManager.requestLocation()
            default:
                isLoading = false
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AppViewModel())
}
