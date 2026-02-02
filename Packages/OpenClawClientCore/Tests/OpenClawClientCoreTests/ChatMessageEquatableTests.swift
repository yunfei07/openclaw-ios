import XCTest
@testable import OpenClawClientCore

final class ChatMessageEquatableTests: XCTestCase {
    func testChatMessageSupportsEquatable() {
        let first = ChatMessage(id: "1", role: .user, text: "Hi", state: .sent)
        let second = ChatMessage(id: "1", role: .user, text: "Hi", state: .sent)
        XCTAssertEqual(first, second)
    }
}
