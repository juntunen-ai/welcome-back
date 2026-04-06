import SwiftUI
import MapKit

/// Detail view for a saved Place — follows the same layout as FamilyMemberProfileView.
struct PlaceDetailView: View {

    let place: Place

    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
    }

    private var hasCoordinates: Bool {
        place.latitude != 0 || place.longitude != 0
    }

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

            if hasCoordinates {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 12))
                    Text(String(format: "%.4f, %.4f", place.latitude, place.longitude))
                        .font(.system(size: 14))
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
            sectionLabel("About This Place")

            Text(place.description.isEmpty
                 ? "No description added yet. Edit in Settings \u{2192} Places."
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
            sectionLabel("Location")

            if hasCoordinates {
                StaticMapView(name: place.name, coordinate: coordinate)
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color.white.opacity(0.08))
                    )
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "map")
                        .font(.system(size: 32))
                        .foregroundColor(.onSurface.opacity(0.2))
                    Text("No coordinates set.\nEdit in Settings \u{2192} Places.")
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

// MARK: - Static Map (UIKit-backed for reliable ScrollView rendering)

/// A UIViewRepresentable that shows a non-interactive map snapshot with a pin.
/// Using MKMapView directly avoids SwiftUI Map rendering issues inside ScrollView.
private struct StaticMapView: UIViewRepresentable {

    let name: String
    let coordinate: CLLocationCoordinate2D

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.isScrollEnabled = false
        mapView.isZoomEnabled = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.showsUserLocation = false
        mapView.mapType = .standard

        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 3000,
            longitudinalMeters: 3000
        )
        mapView.setRegion(region, animated: false)

        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = name
        mapView.addAnnotation(annotation)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 3000,
            longitudinalMeters: 3000
        )
        mapView.setRegion(region, animated: false)

        mapView.removeAnnotations(mapView.annotations)
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = name
        mapView.addAnnotation(annotation)
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
    .preferredColorScheme(.dark)
}
