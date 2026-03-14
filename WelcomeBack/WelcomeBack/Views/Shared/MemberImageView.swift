import SwiftUI

/// Renders a family member's photo from either:
///  • the app's Documents directory  (imageURL starts with `"photo:"`)
///  • the asset catalog              (any other non-empty string)
///  • an initials gradient avatar    (empty imageURL or image not found — requires `name`)
///
/// Usage:
///   MemberImageView(imageURL: member.imageURL, name: member.name, size: 80, cornerRadius: 20)
struct MemberImageView: View {

    let imageURL: String
    var name: String = ""
    let size: CGFloat
    var cornerRadius: CGFloat = 16
    var isCircle: Bool = false

    var body: some View {
        Group {
            if let ui = PersistenceService.loadImage(imageURL: imageURL) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                PersonAvatarPlaceholder(name: name, fontSize: size * 0.42)
            }
        }
        .frame(width: size, height: size)
        .clipShape(isCircle
            ? AnyShape(Circle())
            : AnyShape(RoundedRectangle(cornerRadius: cornerRadius)))
    }
}
