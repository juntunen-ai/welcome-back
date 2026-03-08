import Foundation
import UIKit
import CoreLocation

// MARK: - MemoryAlbum

struct MemoryAlbum: Identifiable {
    let id: String
    var title: String
    var subtitle: String
    var theme: AlbumTheme
    var assetLocalIDs: [String]
    var thumbnail: UIImage?
}

// MARK: - AlbumTheme

enum AlbumTheme {
    case person(familyMemberID: String, name: String)
    case trip(primaryLocation: String)
    case holiday(name: String)
    case scene(tag: String)

    var sectionTitle: String {
        switch self {
        case .person:   return "Family"
        case .trip:     return "Trips"
        case .holiday:  return "Holidays"
        case .scene:    return "Moments"
        }
    }

    var sectionIcon: String {
        switch self {
        case .person:   return "person.2.fill"
        case .trip:     return "airplane"
        case .holiday:  return "star.fill"
        case .scene:    return "sparkles"
        }
    }
}

// MARK: - PhotoItem

/// A single photo ready for display in the carousel, bundled with its metadata.
struct PhotoItem: Identifiable {
    let id: String              // PHAsset.localIdentifier
    let image: UIImage
    let date: Date?
    let location: CLLocation?
}
