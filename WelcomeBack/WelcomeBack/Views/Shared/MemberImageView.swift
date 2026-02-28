import SwiftUI

/// Renders a family member's photo from either:
///  • the app's Documents directory  (imageURL starts with `"photo:"`)
///  • the asset catalog              (any other non-empty string)
///  • a placeholder person icon      (empty imageURL or image not found)
///
/// Usage:
///   MemberImageView(imageURL: member.imageURL, size: 80, cornerRadius: 20)
struct MemberImageView: View {

    let imageURL: String
    let size: CGFloat
    var cornerRadius: CGFloat = 16

    var body: some View {
        Group {
            if let ui = PersistenceService.loadImage(imageURL: imageURL) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.surfaceVariant
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: size * 0.4))
                            .foregroundColor(.onSurface.opacity(0.3))
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}
