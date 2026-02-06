import Foundation

public enum ChatRole: String, Sendable, Equatable, Codable {
    case user
    case assistant
    case system
    case unknown
}

public enum ChatDeliveryState: Sendable, Equatable, Codable {
    case sending
    case sent
    case failed
}

public struct ChatMessageQuote: Identifiable, Sendable, Equatable, Codable {
    public let id: String
    public let author: String
    public let text: String

    public init(id: String, author: String, text: String) {
        self.id = id
        self.author = author
        self.text = text
    }
}

public struct ChatMessage: Identifiable, Sendable, Equatable, Codable {
    public let id: String
    public let role: ChatRole
    public let text: String
    public let state: ChatDeliveryState
    public let createdAt: Date
    public let replyTo: ChatMessageQuote?
    public let forwardedFrom: String?
    public let isEdited: Bool
    public let localDeleted: Bool

    public init(
        id: String = UUID().uuidString,
        role: ChatRole,
        text: String,
        state: ChatDeliveryState,
        createdAt: Date = Date(),
        replyTo: ChatMessageQuote? = nil,
        forwardedFrom: String? = nil,
        isEdited: Bool = false,
        localDeleted: Bool = false
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.state = state
        self.createdAt = createdAt
        self.replyTo = replyTo
        self.forwardedFrom = forwardedFrom
        self.isEdited = isEdited
        self.localDeleted = localDeleted
    }

    public var hasLocalMetadata: Bool {
        replyTo != nil || forwardedFrom != nil || isEdited || localDeleted
    }
}
