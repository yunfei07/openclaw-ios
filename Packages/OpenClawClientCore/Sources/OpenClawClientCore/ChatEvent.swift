import Foundation

public enum ChatEventState: String, Sendable {
    case delta
    case final
    case error
    case unknown
}

public struct ChatEvent: Sendable {
    public let runId: String
    public let sessionKey: String
    public let seq: Int?
    public let state: ChatEventState
    public let message: ChatMessage?
    public let errorMessage: String?

    public init(
        runId: String,
        sessionKey: String,
        seq: Int?,
        state: ChatEventState,
        message: ChatMessage?,
        errorMessage: String?
    ) {
        self.runId = runId
        self.sessionKey = sessionKey
        self.seq = seq
        self.state = state
        self.message = message
        self.errorMessage = errorMessage
    }
}
