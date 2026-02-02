import SwiftUI
import UIKit

struct ChatAvatarView: View {
    let imageName: String

    var body: some View {
        avatarImage
            .resizable()
            .scaledToFill()
            .frame(width: 36, height: 36)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(ChatUIStyle.avatarBorder, lineWidth: 1)
            )
            .shadow(color: ChatUIStyle.avatarShadow, radius: 2, x: 0, y: 1)
    }

    private var avatarImage: Image {
        if let image = UIImage(named: imageName) {
            return Image(uiImage: image)
        }
        return Image(systemName: "person.crop.circle.fill")
    }
}
