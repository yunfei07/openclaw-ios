import Foundation

public protocol ChatHistoryStoring: Sendable {
    func load(sessionKey: String) async -> [ChatMessage]
    func save(sessionKey: String, messages: [ChatMessage]) async
    func clear(sessionKey: String) async
}

public actor FileChatHistoryStore: ChatHistoryStoring {
    private let baseURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(baseURL: URL? = nil) {
        if let baseURL {
            self.baseURL = baseURL
        } else {
            let fallback = FileManager.default.temporaryDirectory.appendingPathComponent("OpenClaw", isDirectory: true)
            self.baseURL = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first?
                .appendingPathComponent("OpenClaw", isDirectory: true) ?? fallback
        }
        try? FileManager.default.createDirectory(at: self.baseURL, withIntermediateDirectories: true)
#if DEBUG
        print("[ChatHistory] store path: \(self.baseURL.path)")
#endif
    }

    public func load(sessionKey: String) async -> [ChatMessage] {
        let url = fileURL(for: sessionKey)
        guard let data = try? Data(contentsOf: url) else { return [] }
        let messages = (try? decoder.decode([ChatMessage].self, from: data)) ?? []
#if DEBUG
        print("[ChatHistory] load \(sessionKey): \(messages.count)")
#endif
        return messages
    }

    public func save(sessionKey: String, messages: [ChatMessage]) async {
        ensureDirectoryExists()
        let url = fileURL(for: sessionKey)
        guard let data = try? encoder.encode(messages) else { return }
        try? data.write(to: url, options: [.atomic])
#if DEBUG
        print("[ChatHistory] save \(sessionKey): \(messages.count)")
#endif
    }

    public func clear(sessionKey: String) async {
        let url = fileURL(for: sessionKey)
        try? FileManager.default.removeItem(at: url)
#if DEBUG
        print("[ChatHistory] clear \(sessionKey)")
#endif
    }

    private func fileURL(for sessionKey: String) -> URL {
        let safeKey = sanitize(sessionKey)
        return baseURL.appendingPathComponent("chat-history-\(safeKey).json")
    }

    private func sanitize(_ sessionKey: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return sessionKey.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }.reduce(into: "") { $0.append($1) }
    }

    private func ensureDirectoryExists() {
        try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
    }
}
