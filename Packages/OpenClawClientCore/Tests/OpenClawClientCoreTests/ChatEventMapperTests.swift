import Testing
import OpenClawProtocol
@testable import OpenClawClientCore

struct ChatEventMapperTests {
    @Test func mapsChatDeltaEvent() throws {
        let message: [String: AnyCodable] = [
            "role": AnyCodable("assistant"),
            "content": AnyCodable([
                AnyCodable(["type": AnyCodable("text"), "text": AnyCodable("Hello")])
            ])
        ]
        let payload: [String: AnyCodable] = [
            "runId": AnyCodable("run-1"),
            "sessionKey": AnyCodable("main"),
            "seq": AnyCodable(1),
            "state": AnyCodable("delta"),
            "message": AnyCodable(message)
        ]
        let evt = EventFrame(type: "event", event: "chat", payload: AnyCodable(payload), seq: 1, stateversion: nil)
        let mapped = ChatEventMapper.from(event: evt)
        #expect(mapped?.state == .delta)
        #expect(mapped?.runId == "run-1")
        #expect(mapped?.message?.text == "Hello")
    }
}
