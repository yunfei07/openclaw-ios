import SwiftUI

struct ChatBubbleView: View {
    let text: String
    let isOutgoing: Bool

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var maxBubbleWidth: CGFloat {
        horizontalSizeClass == .regular ? 420 : 280
    }

    var body: some View {
        Text(text)
            .font(.system(.body, design: .rounded))
            .foregroundStyle(.primary)
            .lineSpacing(3)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: maxBubbleWidth, alignment: .leading)
            .background(isOutgoing ? ChatUIStyle.bubbleOutgoing : ChatUIStyle.bubbleIncoming)
            .clipShape(.rect(cornerRadius: ChatUIStyle.bubbleRadius))
            .shadow(color: ChatUIStyle.bubbleShadow, radius: 6, x: 0, y: 2)
    }
}
