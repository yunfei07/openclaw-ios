import Testing
import OpenClawProtocol
@testable import OpenClawClientCore

struct ChatMessageMapperTests {
    @Test func mapsTextContent() throws {
        let raw: [String: AnyCodable] = [
            "role": AnyCodable("user"),
            "content": AnyCodable("hello")
        ]
        let message = ChatMessageMapper.fromHistory([AnyCodable(raw)]).first
        #expect(message?.role == .user)
        #expect(message?.text == "hello")
    }
}
