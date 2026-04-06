import SwiftUI
import CoreLocation

struct HomeView: View {

    @EnvironmentObject private var appVM: AppViewModel
    @StateObject private var locationManager = HomeLocationManager()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundDark.ignoresSafeArea()

                VStack(spacing: 0) {
                    heroSection
                        .padding(.top, 16)
                        .padding(.horizontal, 24)

                    Spacer(minLength: 8)

                    micButton

                    Spacer(minLength: 8)

                    infoCard
                        .padding(.horizontal, 24)

                    if !appVM.familyMembers.isEmpty {
                        familyCircles
                            .padding(.top, 16)
                            .padding(.horizontal, 24)
                    }

                    Spacer(minLength: 8)

                    introSection
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                }
            }
            .onAppear {
                locationManager.start()
            }
        }
    }

    // MARK: - Hero section

    /// Profile circle on the left, current location on the right.
    private var heroSection: some View {
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
            }

            Spacer()

            locationCard
        }
    }

    private var locationCard: some View {
        VStack(alignment: .trailing, spacing: 5) {
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
                Text(city)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.onSurface)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)

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

    // MARK: - Mic button

    private var micButton: some View {
        ZStack {
            Button(action: appVM.startListening) {
                ZStack {
                    Circle()
                        .fill(Color.accentYellow)
                        .frame(width: 150, height: 150)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.surface, lineWidth: 10)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 16, y: 6)

                    Image(systemName: "mic.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.black)

                    // Curved text around the mic button
                    CurvedText(
                        text: "REMEMBER WHO YOU ARE",
                        radius: 58,
                        fontSize: 11,
                        topArc: true
                    )
                    CurvedText(
                        text: "PRESS TO SPEAK",
                        radius: 58,
                        fontSize: 11,
                        topArc: false
                    )
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start listening")
            .accessibilityHint("Double-tap to begin a voice conversation about your memories")
        }
    }

    // MARK: - Info card

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            let profile = appVM.userProfile

            if !profile.name.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.accentYellow)
                    Text(profile.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.onSurface)
                }
            }

            if !profile.address.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.accentYellow)
                    Text(profile.address)
                        .font(.system(size: 14))
                        .foregroundColor(.onSurface.opacity(0.8))
                }
            }

            if !profile.biography.isEmpty {
                Text(profile.biography)
                    .font(.system(size: 14))
                    .foregroundColor(.onSurface.opacity(0.65))
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.surfaceVariant.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.white.opacity(0.05))
        )
    }

    // MARK: - Intro section

    private var introSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("What is Welcome Back?")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.onSurface.opacity(0.9))

            Text("A compassionate AI companion that helps you remember the people, places, and moments that matter most. Tap the microphone and start talking.")
                .font(.system(size: 13))
                .foregroundColor(.onSurface.opacity(0.5))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Family circles

    private var familyCircles: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Family")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.onSurface.opacity(0.9))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(appVM.familyMembers) { member in
                        NavigationLink(destination: FamilyMemberProfileView(member: member)) {
                            VStack(spacing: 4) {
                                MemberImageView(
                                    imageURL: member.imageURL,
                                    name: member.name,
                                    size: 48,
                                    isCircle: true
                                )
                                .overlay(
                                    Circle().strokeBorder(Color.accentYellow, lineWidth: 2)
                                )

                                Text(member.name.components(separatedBy: " ").first ?? member.name)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.onSurface.opacity(0.7))
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

// MARK: - Curved Text

/// Renders text along an arc of a circle. `topArc: true` curves along the top,
/// `topArc: false` curves along the bottom. Letters always read left-to-right.
struct CurvedText: View {
    let text: String
    let radius: CGFloat
    let fontSize: CGFloat
    var topArc: Bool = true

    var body: some View {
        ZStack {
            ForEach(Array(letterPositions.enumerated()), id: \.offset) { _, item in
                Text(String(item.char))
                    .font(.system(size: fontSize, weight: .bold, design: .default))
                    .tracking(1)
                    .foregroundColor(.black.opacity(0.5))
                    .rotationEffect(.radians(item.rotation))
                    .offset(x: item.x, y: item.y)
            }
        }
    }

    private var letterPositions: [(char: Character, x: CGFloat, y: CGFloat, rotation: Double)] {
        let chars = Array(text)
        let charWidth = Double(fontSize) * 0.65
        let totalAngle = charWidth * Double(chars.count) / Double(radius)

        if topArc {
            // Top arc: center at -π/2 (12 o'clock), letters spread left-to-right
            let startAngle = -.pi / 2 - totalAngle / 2
            return chars.enumerated().map { i, char in
                let angle = startAngle + charWidth / Double(radius) * (Double(i) + 0.5)
                let x = CGFloat(cos(angle)) * radius
                let y = CGFloat(sin(angle)) * radius
                let rotation = angle + .pi / 2
                return (char, x, y, rotation)
            }
        } else {
            // Bottom arc: center at π/2 (6 o'clock), letters spread left-to-right
            let startAngle = .pi / 2 - totalAngle / 2
            return chars.enumerated().map { i, char in
                let angle = startAngle + charWidth / Double(radius) * (Double(i) + 0.5)
                let x = CGFloat(cos(angle)) * radius
                let y = CGFloat(sin(angle)) * radius
                let rotation = angle - .pi / 2
                return (char, x, y, rotation)
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AppViewModel())
}
