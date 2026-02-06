import ExyteChat
import OpenClawClientCore
import SwiftUI

struct TelegramMessageRowView: View {
    let message: ExyteChat.Message
    let localMessage: ChatMessage?
    let positionInGroup: PositionInUserGroup
    let positionInSection: PositionInMessagesSection
    let onLongPress: () -> Void

    private var isOutgoing: Bool {
        message.user.isCurrentUser
    }

    private var showTail: Bool {
        positionInGroup == .last || positionInGroup == .single
    }

    private var isTopInGroup: Bool {
        positionInGroup == .first || positionInGroup == .single
    }

    private var showAvatar: Bool {
        !isOutgoing && (positionInGroup == .last || positionInGroup == .single)
    }

    private var isDeleted: Bool {
        localMessage?.localDeleted == true
    }

    private var forwardedFrom: String? {
        guard !isDeleted else { return nil }
        return localMessage?.forwardedFrom
    }

    private var replyMessage: ReplyMessage? {
        guard !isDeleted else { return nil }
        return message.replyMessage
    }

    private var displayText: String {
        if isDeleted {
            return "消息已删除"
        }
        return message.text
    }

    private var isEdited: Bool {
        !isDeleted && localMessage?.isEdited == true
    }

    private var timeText: String {
        Self.timeFormatter.string(from: message.createdAt)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isOutgoing {
                Spacer(minLength: 36)
            } else {
                if showAvatar {
                    ChatAvatarView(imageName: "assistant")
                } else {
                    Color.clear.frame(width: 36, height: 36)
                }
            }

            ChatBubbleView(isOutgoing: isOutgoing, showTail: showTail) {
                bubbleContent
            }

            if isOutgoing {
                Color.clear.frame(width: 36, height: 1)
            } else {
                Spacer(minLength: 36)
            }
        }
        .frame(maxWidth: .infinity, alignment: isOutgoing ? .trailing : .leading)
        .padding(.horizontal, 12)
        .padding(.top, isTopInGroup ? 8 : 2)
        .padding(.bottom, 2)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.3) {
            onLongPress()
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        let alignment: HorizontalAlignment = isOutgoing ? .trailing : .leading
        VStack(alignment: alignment, spacing: 6) {
            if let forwardedFrom, !forwardedFrom.isEmpty {
                forwardedHeader(name: forwardedFrom)
            }

            if let replyMessage {
                replyPreview(replyMessage)
            }

            Text(displayText)
                .font(.system(size: 16))
                .foregroundStyle(textColor)
                .lineSpacing(2)
                .italic(isDeleted)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: isOutgoing ? .trailing : .leading)

            footer
        }
    }

    private var footer: some View {
        HStack(spacing: 4) {
            if isEdited {
                Text("已编辑")
            }
            Text(timeText)
            if isOutgoing, let status = message.status {
                statusIcon(for: status)
            }
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(ChatUIStyle.bubbleMetaText)
        .frame(maxWidth: .infinity, alignment: isOutgoing ? .trailing : .leading)
    }

    @ViewBuilder
    private func forwardedHeader(name: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "arrowshape.turn.up.right")
                .font(.system(size: 11, weight: .semibold))
            Text("转发自 \(name)")
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(ChatUIStyle.forwardedText)
        .frame(maxWidth: .infinity, alignment: isOutgoing ? .trailing : .leading)
    }

    @ViewBuilder
    private func replyPreview(_ reply: ReplyMessage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(ChatUIStyle.replyStripe)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(reply.user.name)
                    .font(.system(size: 12, weight: .semibold))
                Text(reply.text)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(ChatUIStyle.replyBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var textColor: Color {
        if isDeleted {
            return ChatUIStyle.deletedText
        }
        return isOutgoing ? ChatUIStyle.bubbleOutgoingText : ChatUIStyle.bubbleIncomingText
    }

    @ViewBuilder
    private func statusIcon(for status: ExyteChat.Message.Status) -> some View {
        let image: Image?
        let color: Color
        switch status {
        case .sending:
            image = Image(systemName: "clock")
            color = ChatUIStyle.bubbleMetaText
        case .sent:
            image = Image(systemName: "checkmark")
            color = ChatUIStyle.bubbleMetaText
        case .delivered:
            image = Image(systemName: "checkmark.circle")
            color = ChatUIStyle.bubbleMetaText
        case .read:
            image = Image(systemName: "checkmark.circle.fill")
            color = ChatUIStyle.replyStripe
        case .error:
            image = Image(systemName: "exclamationmark.circle.fill")
            color = ChatUIStyle.errorText
        }
        if let image {
            image
                .foregroundStyle(color)
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
