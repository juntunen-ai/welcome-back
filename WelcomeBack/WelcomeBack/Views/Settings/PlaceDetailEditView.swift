import SwiftUI
import PhotosUI
import MapKit
import CoreLocation
import ImageIO

/// Add or edit a Place — presented as a sheet from PlacesManagementView.
struct PlaceDetailEditView: View {

    @EnvironmentObject private var appVM: AppViewModel
    @Environment(\.dismiss) private var dismiss

    let placeIndex: Int?

    @State private var draft: Place
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoImage: Image?
    @State private var pickedUIImage: UIImage?
    @State private var pickedRawData: Data?       // raw bytes from picker — preserves EXIF
    @State private var photoLocationNote: String?

    // MARK: - Init

    init(placeIndex: Int?, existingPlace: Place? = nil) {
        self.placeIndex = placeIndex
        _draft = State(initialValue: existingPlace ?? Place())
    }

    var isAddMode: Bool { placeIndex == nil }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundDark.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        photoSection
                        nameSection
                        descriptionSection
                        coordinatesSection
                        mapPreview
                        deleteSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(isAddMode ? "Add Place" : draft.name)
            .navigationBarTitleDisplayMode(.large)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.onSurface.opacity(0.6))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(draft.name.isEmpty ? .onSurface.opacity(0.3) : .accentYellow)
                        .disabled(draft.name.isEmpty)
                }
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    guard let newItem else { return }
                    // Load raw data for both display and EXIF extraction.
                    // Keeping raw bytes so savePhotoData can write them as-is,
                    // preserving EXIF GPS metadata for map display in PlaceDetailView.
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        pickedRawData = data
                        if let ui = UIImage(data: data) {
                            pickedUIImage = ui
                            photoImage = Image(uiImage: ui)
                        }
                        // Extract GPS coordinates from EXIF
                        extractGPSFromImageData(data)
                    }
                }
            }
        }
    }

    // MARK: - GPS Extraction

    /// Reads GPS latitude/longitude from image EXIF data and auto-fills coordinates.
    private func extractGPSFromImageData(_ data: Data) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any] else {
            return
        }

        if let lat = gps[kCGImagePropertyGPSLatitude] as? Double,
           let latRef = gps[kCGImagePropertyGPSLatitudeRef] as? String,
           let lon = gps[kCGImagePropertyGPSLongitude] as? Double,
           let lonRef = gps[kCGImagePropertyGPSLongitudeRef] as? String {

            let signedLat = (latRef == "S") ? -lat : lat
            let signedLon = (lonRef == "W") ? -lon : lon

            draft.latitude = signedLat
            draft.longitude = signedLon
            photoLocationNote = String(format: "Coordinates set from photo: %.4f, %.4f", signedLat, signedLon)
        }
    }

    // MARK: - Photo

    private var photoSection: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.surfaceVariant.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)

                if let photoImage {
                    photoImage
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                } else if let ui = PersistenceService.loadImage(imageURL: draft.imageURL) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                } else {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.onSurface.opacity(0.25))
                }
            }

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label("Choose Photo", systemImage: "photo.badge.plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.accentYellow)
            }

            if let note = photoLocationNote {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                    Text(note)
                        .font(.system(size: 12))
                        .foregroundColor(.onSurface.opacity(0.6))
                }
            }
        }
        .padding(.vertical, 12)
        .background(Color.surfaceVariant.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Name

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("Name")

            HStack(spacing: 14) {
                iconBadge("mappin.circle.fill", color: .green)
                TextField("e.g. Summer Cottage, Childhood Home", text: $draft.name)
                    .font(.system(size: 15))
                    .foregroundColor(.onSurface)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.surfaceVariant.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("Description")

            HStack(alignment: .top, spacing: 14) {
                iconBadge("text.quote", color: .purple)
                    .padding(.top, 2)
                TextField("Describe this place and why it matters…",
                          text: $draft.description, axis: .vertical)
                    .font(.system(size: 15))
                    .foregroundColor(.onSurface)
                    .lineLimit(5, reservesSpace: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.surfaceVariant.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Coordinates

    private var coordinatesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("Coordinates")

            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    iconBadge("location.fill", color: .blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Latitude")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.onSurface.opacity(0.45))
                            .textCase(.uppercase)
                            .tracking(0.6)
                        TextField("e.g. 61.50", value: $draft.latitude, format: .number)
                            .font(.system(size: 15))
                            .foregroundColor(.onSurface)
                            .keyboardType(.decimalPad)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)
                    .padding(.leading, 60)

                HStack(spacing: 14) {
                    iconBadge("location.fill", color: .cyan)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Longitude")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.onSurface.opacity(0.45))
                            .textCase(.uppercase)
                            .tracking(0.6)
                        TextField("e.g. 28.10", value: $draft.longitude, format: .number)
                            .font(.system(size: 15))
                            .foregroundColor(.onSurface)
                            .keyboardType(.decimalPad)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color.surfaceVariant.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Map Preview

    @ViewBuilder
    private var mapPreview: some View {
        if draft.latitude != 0 || draft.longitude != 0 {
            let coord = CLLocationCoordinate2D(latitude: draft.latitude, longitude: draft.longitude)

            VStack(alignment: .leading, spacing: 4) {
                sectionHeader("Preview")

                Map(initialPosition: .camera(MapCamera(
                    centerCoordinate: coord,
                    distance: 5000
                ))) {
                    Marker(draft.name.isEmpty ? "Place" : draft.name,
                           coordinate: coord)
                }
                .mapStyle(.standard)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - Delete

    @ViewBuilder
    private var deleteSection: some View {
        if !isAddMode {
            Button {
                if let idx = placeIndex {
                    appVM.userProfile.places.remove(at: idx)
                }
                dismiss()
            } label: {
                HStack {
                    Spacer()
                    Label("Delete Place", systemImage: "trash")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(.vertical, 14)
                .background(Color.red.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
    }

    // MARK: - Utility

    private func iconBadge(_ name: String, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(color)
            .frame(width: 30, height: 30)
            .overlay(
                Image(systemName: name)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            )
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .foregroundColor(.accentYellow)
            .font(.system(size: 12, weight: .bold))
            .tracking(1.5)
            .textCase(.uppercase)
            .padding(.leading, 4)
            .padding(.bottom, 4)
    }

    // MARK: - Save

    private func save() {
        if let rawData = pickedRawData {
            // Prefer raw bytes — preserves EXIF GPS so the detail view can show a map.
            draft.imageURL = PersistenceService.savePhotoData(rawData, memberID: "place_\(draft.id)")
        } else if let ui = pickedUIImage {
            // Fallback: no raw data available (shouldn't happen with PhotosPicker on iOS 16+).
            draft.imageURL = PersistenceService.savePhoto(ui, memberID: "place_\(draft.id)")
        }

        if let index = placeIndex {
            appVM.userProfile.places[index] = draft
        } else {
            appVM.userProfile.places.append(draft)
        }
        dismiss()
    }
}

#Preview {
    PlaceDetailEditView(placeIndex: nil)
        .environmentObject(AppViewModel())
}
