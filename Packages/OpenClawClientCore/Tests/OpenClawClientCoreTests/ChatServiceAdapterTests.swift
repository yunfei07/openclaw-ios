import Foundation
import Testing
import OpenClawProtocol
import OpenClawSDK
@testable import OpenClawClientCore

final class MockGateway: GatewayRequesting, GatewayEventStreaming, @unchecked Sendable {
    var lastMethod: String?
    var lastPayload: Data?
    private let eventFrames: [EventFrame]

    init(events: [EventFrame] = []) {
        self.eventFrames = events
    }

    func request(method: String, payload: Data) async throws -> Data {
        lastMethod = method
        lastPayload = payload
        return try JSONEncoder().encode(ChatHistoryResponse(sessionKey: "main", sessionId: nil, messages: [], thinkingLevel: nil))
    }

    func events() async -> AsyncStream<EventFrame> {
        let frames = eventFrames
        return AsyncStream { continuation in
            for frame in frames {
                continuation.yield(frame)
            }
            continuation.finish()
        }
    }
}

struct ChatServiceAdapterTests {
    @Test func historyCallsChatHistory() async throws {
        let gateway = MockGateway()
        let adapter = ChatServiceAdapter(gateway: gateway)
        _ = try await adapter.history(sessionKey: "main")
        #expect(gateway.lastMethod == "chat.history")
    }

    @Test func eventsMapChatPayload() async throws {
        let payload: [String: AnyCodable] = [
            "runId": AnyCodable("run-1"),
            "sessionKey": AnyCodable("main"),
            "state": AnyCodable("delta")
        ]
        let frame = EventFrame(type: "event", event: "chat", payload: AnyCodable(payload), seq: 1, stateversion: nil)
        let gateway = MockGateway(events: [frame])
        let adapter = ChatServiceAdapter(gateway: gateway)
        var iterator = adapter.events().makeAsyncIterator()
        let event = await iterator.next()
        #expect(event?.runId == "run-1")
    }
}
