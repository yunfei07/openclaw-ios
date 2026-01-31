import Foundation
import OpenClawProtocol

public enum ChatMessageMapper {
    public static func fromHistory(_ messages: [AnyCodable]?) -> [ChatMessage] {
        guard let messages else { return [] }
        return messages.compactMap { toChatMessage($0) }
    }

    private static func toChatMessage(_ raw: AnyCodable) -> ChatMessage? {
        guard let dict = raw.value as? [String: AnyCodable] else { return nil }
        let role = (dict["role"]?.value as? String).map(ChatRole.from) ?? .unknown
        let text = extractText(from: dict)
        return ChatMessage(role: role, text: text, state: .sent)
    }

    private static func extractText(from dict: [String: AnyCodable]) -> String {
        if let content = dict["content"]?.value as? String { return content }
        if let content = dict["text"]?.value as? String { return content }
        if let parts = dict["content"]?.value as? [AnyCodable] {
            let texts = parts.compactMap { part -> String? in
                guard let entry = part.value as? [String: AnyCodable] else { return nil }
                guard (entry["type"]?.value as? String) == "text" else { return nil }
                return entry["text"]?.value as? String
            }
            if !texts.isEmpty { return texts.joined() }
        }
        return "(unsupported message)"
    }
}

private extension ChatRole {
    static func from(_ value: String) -> ChatRole {
        switch value.lowercased() {
        case "user": return .user
        case "assistant": return .assistant
        case "system": return .system
        default: return .unknown
        }
    }
}
