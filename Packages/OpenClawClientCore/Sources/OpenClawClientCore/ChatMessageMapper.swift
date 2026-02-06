import Foundation
import OpenClawProtocol

public enum ChatMessageMapper {
    public static func fromHistory(_ messages: [AnyCodable]?) -> [ChatMessage] {
        guard let messages else { return [] }
        let now = Date()
        let total = max(messages.count, 1)
        return messages.enumerated().compactMap { index, raw in
            let offset = TimeInterval(index - (total - 1)) * 60
            let fallback = now.addingTimeInterval(offset)
            return toChatMessage(raw, fallback: fallback, index: index)
        }
    }

    private static func toChatMessage(_ raw: AnyCodable, fallback: Date, index: Int) -> ChatMessage? {
        guard let dict = raw.value as? [String: AnyCodable] else { return nil }
        let role = (dict["role"]?.value as? String).map(ChatRole.from) ?? .unknown
        let text = extractText(from: dict)
        let parsedTimestamp = parseTimestamp(from: dict)
        let createdAt = parsedTimestamp ?? fallback
        let id = (dict["id"]?.value as? String) ?? stableId(
            role: role,
            text: text,
            createdAt: createdAt,
            index: index,
            hasTimestamp: parsedTimestamp != nil
        )
        return ChatMessage(id: id, role: role, text: text, state: .sent, createdAt: createdAt)
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

    private static func parseTimestamp(from dict: [String: AnyCodable]) -> Date? {
        let candidate = dict["timestamp"]?.value
            ?? dict["createdAtMs"]?.value
            ?? dict["ts"]?.value
        if let date = candidate as? Date {
            return date
        }
        if let text = candidate as? String {
            if let raw = Double(text) {
                let seconds = raw > 10_000_000_000 ? raw / 1000.0 : raw
                return Date(timeIntervalSince1970: seconds)
            }
            if let date = ISO8601DateFormatter().date(from: text) {
                return date
            }
        }
        guard let number = candidate as? NSNumber else { return nil }
        let raw = number.doubleValue
        if raw <= 0 { return nil }
        let seconds = raw > 10_000_000_000 ? raw / 1000.0 : raw
        return Date(timeIntervalSince1970: seconds)
    }

    private static func stableId(role: ChatRole, text: String, createdAt: Date, index: Int, hasTimestamp: Bool) -> String {
        if hasTimestamp {
            let ts = Int(createdAt.timeIntervalSince1970 * 1000)
            return "r-\(role.rawValue)-\(ts)-\(text.hashValue)"
        }
        return "r-\(role.rawValue)-\(index)-\(text.hashValue)"
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
