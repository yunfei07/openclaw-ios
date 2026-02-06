import SwiftUI
import UIKit

enum ChatUIStyle {
    static let background = LinearGradient(
        colors: [
            Color(uiColor: UIColor { trait in
                if trait.userInterfaceStyle == .dark {
                    return UIColor(red: 0.08, green: 0.10, blue: 0.12, alpha: 1.0)
                }
                return UIColor(red: 0.90, green: 0.95, blue: 0.99, alpha: 1.0)
            }),
            Color(uiColor: UIColor { trait in
                if trait.userInterfaceStyle == .dark {
                    return UIColor(red: 0.05, green: 0.07, blue: 0.09, alpha: 1.0)
                }
                return UIColor(red: 0.98, green: 0.99, blue: 1.0, alpha: 1.0)
            }),
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let bubbleIncoming = Color(
        uiColor: UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(red: 0.16, green: 0.17, blue: 0.20, alpha: 1.0)
            }
            return UIColor(white: 1.0, alpha: 1.0)
        }
    )
    static let bubbleOutgoing = Color(
        uiColor: UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(red: 0.18, green: 0.33, blue: 0.45, alpha: 1.0)
            }
            return UIColor(red: 0.86, green: 0.95, blue: 1.0, alpha: 1.0)
        }
    )
    static let bubbleRadius: CGFloat = 18
    static let bubbleShadow = Color.black.opacity(0.04)
    static let bubbleIncomingBorder = Color(
        uiColor: UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(white: 1.0, alpha: 0.08)
            }
            return UIColor(white: 0.0, alpha: 0.06)
        }
    )
    static let bubbleOutgoingBorder = Color(
        uiColor: UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(white: 0.0, alpha: 0.2)
            }
            return UIColor(red: 0.56, green: 0.80, blue: 0.95, alpha: 0.45)
        }
    )

    static let bubbleIncomingText = Color(
        uiColor: UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(white: 0.95, alpha: 1.0)
            }
            return UIColor(white: 0.12, alpha: 1.0)
        }
    )
    static let bubbleOutgoingText = Color(
        uiColor: UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(white: 0.96, alpha: 1.0)
            }
            return UIColor(white: 0.10, alpha: 1.0)
        }
    )
    static let bubbleMetaText = Color(.secondaryLabel)
    static let replyStripe = Color(uiColor: UIColor.systemBlue)
    static let replyBackground = Color(uiColor: UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(white: 1.0, alpha: 0.08)
        }
        return UIColor(white: 0.0, alpha: 0.04)
    })
    static let forwardedText = Color(.secondaryLabel)
    static let deletedText = Color(.secondaryLabel)
    static let errorText = Color(.systemRed)

    static let inputBackground = Color(.systemBackground)
    static let inputBorder = Color(.separator).opacity(0.35)
    static let sendButton = Color(.systemBlue)
    static let sendButtonDisabled = Color(.systemGray4)

    static let statusPillBackground = Color(.secondarySystemBackground)
    static let statusPillText = Color(.secondaryLabel)

    static let cardBackground = Color(.systemBackground)
    static let cardBorder = Color(.separator).opacity(0.3)

    static let avatarBorder = Color.black.opacity(0.12)
    static let avatarShadow = Color.black.opacity(0.18)
}
