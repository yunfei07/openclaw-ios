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

public struct ChatMessage: Identifiable, Sendable, Equatable, Codable {
    public let id: String
    public let role: ChatRole
    public let text: String
    public let state: ChatDeliveryState

    public init(id: String = UUID().uuidString, role: ChatRole, text: String, state: ChatDeliveryState) {
        self.id = id
        self.role = role
        self.text = text
        self.state = state
    }
}
