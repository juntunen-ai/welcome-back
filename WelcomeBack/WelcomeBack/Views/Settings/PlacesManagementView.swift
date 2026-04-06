import SwiftUI

/// Manage saved places — accessible from Settings → Places.
struct PlacesManagementView: View {

    @EnvironmentObject private var appVM: AppViewModel
    @State private var showingAddSheet = false
    @State private var editingPlaceIndex: Int? = nil

    var body: some View {
        ZStack {
            Color.backgroundDark.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    if appVM.userProfile.places.isEmpty {
                        emptyState
                            .padding(.horizontal, 16)
                            .padding(.top, 40)
                    } else {
                        placesList
                            .padding(.horizontal, 16)
                    }

                    addPlaceButton
                        .padding(.horizontal, 16)
                        .padding(.top, 4)

                    Spacer(minLength: 24)
                }
                .padding(.top, 8)
            }
        }
        .navigationTitle("Places")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingAddSheet) {
            PlaceDetailEditView(placeIndex: nil)
                .environmentObject(appVM)
        }
        .sheet(item: $editingPlaceIndex) { index in
            PlaceDetailEditView(
                placeIndex: index,
                existingPlace: appVM.userProfile.places[index]
            )
            .environmentObject(appVM)
        }
    }

    // MARK: - Subviews

    private var placesList: some View {
        VStack(spacing: 12) {
            ForEach(Array(appVM.userProfile.places.enumerated()), id: \.element.id) { index, place in
                PlaceRowView(place: place)
                    .onTapGesture { editingPlaceIndex = index }
            }
        }
    }

    private var addPlaceButton: some View {
        Button { showingAddSheet = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                Text("Add place")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.backgroundDark)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.accentYellow)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 48))
                .foregroundColor(.onSurface.opacity(0.3))

            VStack(spacing: 6) {
                Text("No places yet")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.onSurface)

                Text("Tap \"Add place\" to save important locations")
                    .font(.system(size: 14))
                    .foregroundColor(.onSurface.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.surfaceVariant.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

// MARK: - Place Row

struct PlaceRowView: View {

    let place: Place

    var body: some View {
        HStack(spacing: 14) {
            // Thumbnail
            MemberImageView(imageURL: place.imageURL, name: place.name, size: 56, cornerRadius: 14)
                .overlay(
                    Group {
                        if PersistenceService.loadImage(imageURL: place.imageURL) == nil {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.onSurface.opacity(0.3))
                        }
                    }
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(place.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.onSurface)
                    .lineLimit(1)

                if !place.description.isEmpty {
                    Text(place.description)
                        .font(.system(size: 13))
                        .foregroundColor(.onSurface.opacity(0.5))
                        .lineLimit(2)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.onSurface.opacity(0.3))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.surfaceVariant.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    NavigationStack {
        PlacesManagementView()
            .environmentObject(AppViewModel())
    }
}
