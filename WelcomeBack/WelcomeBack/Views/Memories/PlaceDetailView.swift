import SwiftUI
import MapKit
import CoreLocation
import ImageIO

/// Detail view for a saved Place — follows the same layout as FamilyMemberProfileView.
struct PlaceDetailView: View {

    let place: Place

    @EnvironmentObject private var lang: LanguageManager

    // Resolved coordinate: from model if set, otherwise extracted from photo EXIF on appear.
    @State private var resolvedCoordinate: CLLocationCoordinate2D?
    // Human-readable address from reverse geocoding.
    @State private var locationLabel: String?

    private var modelCoordinate: CLLocationCoordinate2D? {
        guard place.latitude != 0 || place.longitude != 0 else { return nil }
        return CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
    }

    private var displayCoordinate: CLLocationCoordinate2D? {
        resolvedCoordinate ?? modelCoordinate
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.backgroundDark.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    heroImage
                    titleSection
                    descriptionSection
                    mapSection
                    Spacer(minLength: 40)
                }
                .padding(.bottom, 16)
            }
        }
        .navigationTitle(place.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await resolveLocation()
        }
    }

    // MARK: - Location resolution

    /// Resolves coordinates: uses model values if set, otherwise extracts from photo EXIF.
    /// Then reverse-geocodes the coordinate to a human-readable address.
    private func resolveLocation() async {
        var coord = modelCoordinate

        // If no coordinates stored, try extracting from the photo's EXIF data.
        // We read raw file bytes (not UIImage) so EXIF is never stripped.
        if coord == nil, !place.imageURL.isEmpty,
           let rawData = PersistenceService.loadImageData(imageURL: place.imageURL),
           let extracted = extractGPS(fromRawData: rawData) {
            coord = extracted
            await MainActor.run { resolvedCoordinate = extracted }
        }

        // Reverse geocode to a readable address.
        if let coord {
            let geocoder = CLGeocoder()
            let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            if let placemarks = try? await geocoder.reverseGeocodeLocation(location),
               let placemark = placemarks.first {
                let parts = [placemark.locality, placemark.administrativeArea, placemark.country]
                    .compactMap { $0 }
                let label = parts.prefix(2).joined(separator: ", ")
                if !label.isEmpty {
                    await MainActor.run { locationLabel = label }
                }
            }
        }
    }

    /// Extracts GPS coordinates from raw image file bytes.
    /// Must receive the original file data — never pass UIImage.jpegData() output,
    /// as re-encoding strips all EXIF metadata.
    private func extractGPS(fromRawData data: Data) -> CLLocationCoordinate2D? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any],
              let lat = gps[kCGImagePropertyGPSLatitude] as? Double,
              let latRef = gps[kCGImagePropertyGPSLatitudeRef] as? String,
              let lon = gps[kCGImagePropertyGPSLongitude] as? Double,
              let lonRef = gps[kCGImagePropertyGPSLongitudeRef] as? String
        else { return nil }

        return CLLocationCoordinate2D(
            latitude:  latRef == "S" ? -lat : lat,
            longitude: lonRef == "W" ? -lon : lon
        )
    }

    // MARK: - Hero Image

    private var heroImage: some View {
        ZStack {
            if let ui = PersistenceService.loadImage(imageURL: place.imageURL) {
                GeometryReader { geo in
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
                .frame(height: 300)
            } else {
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.15, green: 0.60, blue: 0.35),
                            Color(red: 0.15, green: 0.60, blue: 0.35).opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundColor(.white.opacity(0.25))
                }
                .frame(height: 220)
            }
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(place.name)
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.onSurface)

            if let coord = displayCoordinate {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 12))
                    if let label = locationLabel {
                        Text(label)
                            .font(.system(size: 14))
                    } else {
                        Text(String(format: "%.4f, %.4f", coord.latitude, coord.longitude))
                            .font(.system(size: 14))
                    }
                }
                .foregroundColor(.onSurface.opacity(0.55))
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel(lang.t("memories.place.about"))

            Text(place.description.isEmpty
                 ? lang.t("memories.place.no_desc")
                 : place.description)
                .font(.system(size: 16))
                .foregroundColor(place.description.isEmpty ? .onSurface.opacity(0.35) : .onSurface.opacity(0.85))
                .lineSpacing(4)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.surfaceVariant.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Map

    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel(lang.t("memories.place.location"))

            if let coord = displayCoordinate {
                ZStack(alignment: .bottomTrailing) {
                    // Hybrid satellite map with pin — UIKit-backed for reliable ScrollView rendering
                    HybridMapView(name: place.name, coordinate: coord)
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(Color.white.opacity(0.08))
                        )

                    // Open in Maps button
                    Button {
                        openInMaps(coordinate: coord)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                                .font(.system(size: 14))
                            Text(lang.t("memories.place.maps"))
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    }
                    .padding(12)
                }

                // Show "coordinates from photo" note if model had no coords
                if modelCoordinate == nil, resolvedCoordinate != nil {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.badge.checkmark")
                            .font(.system(size: 11))
                            .foregroundColor(.green)
                        Text(lang.t("memories.place.photo_loc"))
                            .font(.system(size: 12))
                            .foregroundColor(.onSurface.opacity(0.5))
                    }
                    .padding(.horizontal, 4)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "map")
                        .font(.system(size: 32))
                        .foregroundColor(.onSurface.opacity(0.2))
                    Text(lang.t("memories.place.no_loc"))
                        .font(.system(size: 14))
                        .foregroundColor(.onSurface.opacity(0.35))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color.surfaceVariant.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Actions

    private func openInMaps(coordinate: CLLocationCoordinate2D) {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = place.name
        item.openInMaps(launchOptions: [MKLaunchOptionsMapTypeKey: MKMapType.standard.rawValue])
    }

    // MARK: - Utility

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .foregroundColor(.accentYellow)
            .font(.system(size: 12, weight: .bold))
            .tracking(1.5)
            .textCase(.uppercase)
            .padding(.leading, 4)
    }
}

// MARK: - Hybrid Satellite Map (UIKit-backed for reliable ScrollView rendering)

/// MKMapView in hybrid satellite style with a pin. UIKit-backed to avoid SwiftUI Map
/// scroll conflicts inside ScrollView. Non-interactive so scrolling the page works normally.
private struct HybridMapView: UIViewRepresentable {

    let name: String
    let coordinate: CLLocationCoordinate2D

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.isScrollEnabled = false
        map.isZoomEnabled = false
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        map.showsUserLocation = false
        map.mapType = .hybridFlyover        // satellite + labels + 3D where available
        configure(map)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        configure(map)
    }

    private func configure(_ map: MKMapView) {
        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 1500,        // tighter zoom for individual place view
            longitudinalMeters: 1500
        )
        map.setRegion(region, animated: false)
        map.removeAnnotations(map.annotations)
        let pin = MKPointAnnotation()
        pin.coordinate = coordinate
        pin.title = name
        map.addAnnotation(pin)
    }
}

#Preview {
    NavigationStack {
        PlaceDetailView(place: Place(
            name: "Saimaa Cottage",
            description: "Our family summer cottage on Lake Saimaa. Three weeks every July \u{2014} swimming, fishing, picking blueberries, and watching sunsets turn the water pink and gold.",
            latitude: 61.50, longitude: 28.10
        ))
    }
    .environmentObject(LanguageManager())
    .preferredColorScheme(.dark)
}
