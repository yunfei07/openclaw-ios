import SwiftUI
import UIKit

enum ChatUIStyle {
    static let background = LinearGradient(
        colors: [
            Color(.systemGroupedBackground),
            Color(.secondarySystemBackground),
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let bubbleIncoming = Color(
        uiColor: UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(red: 0.18, green: 0.18, blue: 0.19, alpha: 1.0)
            }
            return UIColor(red: 0.93, green: 0.94, blue: 0.95, alpha: 1.0)
        }
    )
    static let bubbleOutgoing = Color(
        uiColor: UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(red: 0.36, green: 0.82, blue: 0.38, alpha: 1.0)
            }
            return UIColor(red: 0.58, green: 0.93, blue: 0.41, alpha: 1.0)
        }
    )
    static let bubbleRadius: CGFloat = 18
    static let bubbleShadow = Color.black.opacity(0.01)
    static let bubbleIncomingBorder = Color(
        uiColor: UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(white: 1.0, alpha: 0.08)
            }
            return UIColor(white: 0.0, alpha: 0.06)
        }
    )
    static let bubbleOutgoingBorder = Color.black.opacity(0.08)

    static let bubbleIncomingText = Color(
        uiColor: UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(white: 0.94, alpha: 1.0)
            }
            return UIColor(white: 0.12, alpha: 1.0)
        }
    )
    static let bubbleOutgoingText = Color.black.opacity(0.92)

    static let inputBackground = Color(.systemBackground)
    static let inputBorder = Color(.separator).opacity(0.35)
    static let sendButton = Color(.systemGreen)
    static let sendButtonDisabled = Color(.systemGray4)

    static let statusPillBackground = Color(.secondarySystemBackground)
    static let statusPillText = Color(.secondaryLabel)
    static let errorText = Color(.systemRed)

    static let cardBackground = Color(.systemBackground)
    static let cardBorder = Color(.separator).opacity(0.3)

    static let avatarBorder = Color.black.opacity(0.12)
    static let avatarShadow = Color.black.opacity(0.18)
}
