import XCTest
@testable import OpenClawClientCore

final class ChatMessageEquatableTests: XCTestCase {
    func testChatMessageSupportsEquatable() {
        let quote = ChatMessageQuote(id: "q1", author: "Alice", text: "hello")
        let timestamp = Date(timeIntervalSince1970: 1)
        let first = ChatMessage(
            id: "1",
            role: .user,
            text: "Hi",
            state: .sent,
            createdAt: timestamp,
            replyTo: quote,
            forwardedFrom: "Bob",
            isEdited: true,
            localDeleted: false
        )
        let second = ChatMessage(
            id: "1",
            role: .user,
            text: "Hi",
            state: .sent,
            createdAt: timestamp,
            replyTo: quote,
            forwardedFrom: "Bob",
            isEdited: true,
            localDeleted: false
        )
        XCTAssertEqual(first, second)
    }
}
