import SwiftUI

enum ChatUIStyle {
    static let background = LinearGradient(
        colors: [
            Color(.systemGroupedBackground),
            Color(.secondarySystemBackground),
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let bubbleIncoming = Color(.systemBackground)
    static let bubbleOutgoing = Color(red: 0.90, green: 0.97, blue: 0.91)
    static let bubbleRadius: CGFloat = 20
    static let bubbleShadow = Color.black.opacity(0.04)

    static let inputBackground = Color(.systemBackground)
    static let inputBorder = Color(.separator).opacity(0.35)
    static let sendButton = Color(.systemGreen)
    static let sendButtonDisabled = Color(.systemGray4)

    static let statusPillBackground = Color(.secondarySystemBackground)
    static let statusPillText = Color(.secondaryLabel)
    static let errorText = Color(.systemRed)

    static let cardBackground = Color(.systemBackground)
    static let cardBorder = Color(.separator).opacity(0.3)
}
