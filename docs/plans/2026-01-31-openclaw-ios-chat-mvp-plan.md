# OpenClaw iOS Chat MVP Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a minimal iOS chat app that lets users configure a Gateway URL + token, connect, and call chat.history / chat.send / chat.abort.

**Architecture:** Keep UI thin (SwiftUI + @Observable view model). Core logic lives in a local Swift package `OpenClawClientCore` with tests. The app target depends on the package and wires UI to `ChatViewModel`.

**Tech Stack:** Swift 6.2, SwiftUI, Observation, URLSessionWebSocketTask, OpenClawSDK/OpenClawProtocol, Swift Testing.

---

### Task 1: Create local core package (config-only)

**Files:**
- Create: `Packages/OpenClawClientCore/Package.swift`
- Create: `Packages/OpenClawClientCore/Sources/OpenClawClientCore/`
- Create: `Packages/OpenClawClientCore/Tests/OpenClawClientCoreTests/`

**Step 1: Initialize Swift package (TDD exception: config)**

Run:
```bash
mkdir -p Packages/OpenClawClientCore
cd Packages/OpenClawClientCore
swift package init --type library --name OpenClawClientCore
```

**Step 2: Replace Package.swift (TDD exception: config)**

Write:
```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "OpenClawClientCore",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "OpenClawClientCore", targets: ["OpenClawClientCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/yunfei07/openclaw-ios-sdk.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "OpenClawClientCore",
            dependencies: [
                .product(name: "OpenClawSDK", package: "openclaw-ios-sdk"),
                .product(name: "OpenClawProtocol", package: "openclaw-ios-sdk"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "OpenClawClientCoreTests",
            dependencies: ["OpenClawClientCore"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("SwiftTesting"),
            ]
        ),
    ]
)
```

**Step 3: Commit**

```bash
git add Packages/OpenClawClientCore/Package.swift
 git commit -m "chore: add OpenClawClientCore package"
```

---

### Task 2: Add local package to Xcode project (config-only)

**Files:**
- Modify: `openclaw-ios.xcodeproj/project.pbxproj`

**Step 1: Add package dependency (TDD exception: config)**

Use Xcode:
1. Open `openclaw-ios.xcodeproj`
2. File → Add Packages… → Add Local Package…
3. Select `Packages/OpenClawClientCore`
4. Add product `OpenClawClientCore` to target `openclaw-ios`

**Step 2: Commit**

```bash
git add openclaw-ios.xcodeproj/project.pbxproj
 git commit -m "chore: add OpenClawClientCore to app"
```

---

### Task 3: Settings store + keychain token (TDD)

**Files:**
- Create: `Packages/OpenClawClientCore/Sources/OpenClawClientCore/SettingsStore.swift`
- Create: `Packages/OpenClawClientCore/Sources/OpenClawClientCore/KeychainSecretStore.swift`
- Create: `Packages/OpenClawClientCore/Tests/OpenClawClientCoreTests/SettingsStoreTests.swift`

**Step 1: Write failing tests** (`SettingsStoreTests.swift`)

```swift
import Foundation
import Testing
@testable import OpenClawClientCore

struct SettingsStoreTests {
    @Test func savesAndLoadsGatewaySettings() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let secrets = InMemorySecretStore()
        let store = SettingsStore(defaults: defaults, secrets: secrets)

        store.saveGatewayUrl("ws://127.0.0.1:18789")
        store.saveGatewayToken("tok")

        #expect(store.loadGatewayUrl() == "ws://127.0.0.1:18789")
        #expect(store.loadGatewayToken() == "tok")
    }

    @Test func clearsGatewayToken() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let secrets = InMemorySecretStore()
        let store = SettingsStore(defaults: defaults, secrets: secrets)

        store.saveGatewayToken("tok")
        store.clearGatewayToken()

        #expect(store.loadGatewayToken() == nil)
    }
}
```

**Step 2: Run test to verify it fails**

Run:
```bash
swift test --package-path Packages/OpenClawClientCore --filter SettingsStoreTests
```
Expected: FAIL (SettingsStore/SecretStore missing).

**Step 3: Write minimal implementation**

`KeychainSecretStore.swift`:
```swift
import Foundation
import Security

public protocol SecretStoring: Sendable {
    func load(key: String) -> String?
    func save(key: String, value: String)
    func delete(key: String)
}

public final class InMemorySecretStore: SecretStoring, @unchecked Sendable {
    private var values: [String: String] = [:]
    public init() {}
    public func load(key: String) -> String? { values[key] }
    public func save(key: String, value: String) { values[key] = value }
    public func delete(key: String) { values.removeValue(forKey: key) }
}

public final class KeychainSecretStore: SecretStoring {
    private let service: String

    public init(service: String = "openclaw-ios") {
        self.service = service
    }

    public func load(key: String) -> String? {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecReturnData: true,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func save(key: String, value: String) {
        delete(key: key)
        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    public func delete(key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

`SettingsStore.swift`:
```swift
import Foundation

public final class SettingsStore: Sendable {
    private let defaults: UserDefaults
    private let secrets: SecretStoring
    private let urlKey = "gateway.url"
    private let tokenKey = "gateway.token"

    public init(defaults: UserDefaults = .standard, secrets: SecretStoring) {
        self.defaults = defaults
        self.secrets = secrets
    }

    public func loadGatewayUrl() -> String? {
        defaults.string(forKey: urlKey)
    }

    public func saveGatewayUrl(_ value: String) {
        defaults.set(value.trimmingCharacters(in: .whitespacesAndNewlines), forKey: urlKey)
    }

    public func loadGatewayToken() -> String? {
        secrets.load(key: tokenKey)
    }

    public func saveGatewayToken(_ value: String) {
        secrets.save(key: tokenKey, value: value)
    }

    public func clearGatewayToken() {
        secrets.delete(key: tokenKey)
    }
}
```

**Step 4: Re-run tests**

```bash
swift test --package-path Packages/OpenClawClientCore --filter SettingsStoreTests
```
Expected: PASS.

**Step 5: Commit**

```bash
git add Packages/OpenClawClientCore/Sources/OpenClawClientCore/SettingsStore.swift \
  Packages/OpenClawClientCore/Sources/OpenClawClientCore/KeychainSecretStore.swift \
  Packages/OpenClawClientCore/Tests/OpenClawClientCoreTests/SettingsStoreTests.swift
 git commit -m "feat: add gateway settings store"
```

---

### Task 4: GatewayConnection (connect + request) (TDD)

**Files:**
- Create: `Packages/OpenClawClientCore/Sources/OpenClawClientCore/GatewayConnection.swift`
- Create: `Packages/OpenClawClientCore/Tests/OpenClawClientCoreTests/GatewayConnectionTests.swift`

**Step 1: Write failing tests** (`GatewayConnectionTests.swift`)

```swift
import Foundation
import Testing
import OpenClawProtocol
@testable import OpenClawClientCore

final class MockWebSocket: WebSocketTasking, @unchecked Sendable {
    var sent: [URLSessionWebSocketTask.Message] = []
    var inbound: [URLSessionWebSocketTask.Message] = []
    var state: URLSessionTask.State = .running

    func resume() {}
    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {}

    func send(_ message: URLSessionWebSocketTask.Message) async throws {
        sent.append(message)
    }

    func receive() async throws -> URLSessionWebSocketTask.Message {
        if inbound.isEmpty { throw NSError(domain: "Mock", code: 1) }
        return inbound.removeFirst()
    }

    func receive(completionHandler: @escaping @Sendable (Result<URLSessionWebSocketTask.Message, Error>) -> Void) {
        if inbound.isEmpty {
            completionHandler(.failure(NSError(domain: "Mock", code: 1)))
        } else {
            completionHandler(.success(inbound.removeFirst()))
        }
    }
}

final class RecordingTokenStore: TokenStoring, @unchecked Sendable {
    var stored: DeviceAuthEntry?
    func loadToken(deviceId: String, role: String) -> DeviceAuthEntry? { nil }
    func storeToken(deviceId: String, role: String, token: String, scopes: [String]) -> DeviceAuthEntry {
        let entry = DeviceAuthEntry(token: token, role: role, scopes: scopes, updatedAtMs: 1)
        stored = entry
        return entry
    }
    func clearToken(deviceId: String, role: String) {}
}

struct GatewayConnectionTests {
    @Test func requestReturnsResponsePayload() async throws {
        let socket = MockWebSocket()
        let tokenStore = RecordingTokenStore()
        let identityStore = DeviceIdentityStore(rootURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let conn = GatewayConnection(url: URL(string: "ws://127.0.0.1:18789")!, tokenStore: tokenStore, identityStore: identityStore, socket: socket)

        let payload = ResponseFrame(type: "res", id: "req-1", ok: true, payload: AnyCodable(["ok": AnyCodable(true)]), error: nil)
        let frame = GatewayFrame.res(payload)
        let data = try JSONEncoder().encode(frame)
        socket.inbound = [.data(data)]

        let result = try await conn.request(method: "health", payload: Data())
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: result)
        #expect(decoded.value as? [String: AnyCodable] != nil)
    }
}
```

**Step 2: Run test to verify it fails**

```bash
swift test --package-path Packages/OpenClawClientCore --filter GatewayConnectionTests
```
Expected: FAIL (GatewayConnection/WebSocketTasking missing).

**Step 3: Write minimal implementation** (`GatewayConnection.swift`)

```swift
import Foundation
import OpenClawProtocol
import OpenClawSDK

public protocol WebSocketTasking: AnyObject, Sendable {
    var state: URLSessionTask.State { get }
    func resume()
    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?)
    func send(_ message: URLSessionWebSocketTask.Message) async throws
    func receive() async throws -> URLSessionWebSocketTask.Message
    func receive(completionHandler: @escaping @Sendable (Result<URLSessionWebSocketTask.Message, Error>) -> Void)
}

extension URLSessionWebSocketTask: WebSocketTasking {}
extension URLSessionWebSocketTask: @unchecked Sendable {}

public actor GatewayConnection: GatewayRequesting {
    private let url: URL
    private let tokenStore: TokenStoring
    private let identityStore: DeviceIdentityStore
    private let socket: WebSocketTasking
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(
        url: URL,
        tokenStore: TokenStoring,
        identityStore: DeviceIdentityStore,
        socket: WebSocketTasking? = nil
    ) {
        self.url = url
        self.tokenStore = tokenStore
        self.identityStore = identityStore
        if let socket {
            self.socket = socket
        } else {
            let task = URLSession(configuration: .default).webSocketTask(with: url)
            task.maximumMessageSize = 16 * 1024 * 1024
            self.socket = task
        }
    }

    public func connect(sharedToken: String?) async throws {
        socket.resume()
        let identity = identityStore.loadOrCreate()
        let challengeNonce = await receiveChallenge()
        let stored = tokenStore.loadToken(deviceId: identity.deviceId, role: "operator")?.token
        let token = stored ?? sharedToken

        let params = ConnectPayloadBuilder.build(
            clientId: "openclaw-ios",
            clientMode: "ui",
            displayName: "iOS",
            role: "operator",
            scopes: ["operator.read", "operator.write"],
            token: token,
            challengeNonce: challengeNonce,
            identity: identity
        )

        let paramsData = try encoder.encode(params)
        let paramsJson = try JSONSerialization.jsonObject(with: paramsData) as? [String: Any] ?? [:]
        let frame = RequestFrame(type: "req", id: "connect", method: "connect", params: AnyCodable(paramsJson))
        try await socket.send(.data(try encoder.encode(frame)))

        let resFrame = try await receiveResponse(id: "connect")
        guard resFrame.ok, let payload = resFrame.payload else {
            throw NSError(domain: "Gateway", code: 1, userInfo: [NSLocalizedDescriptionKey: "connect failed"])
        }
        let okData = try encoder.encode(payload)
        let ok = try decoder.decode(HelloOk.self, from: okData)
        if let auth = ok.auth, let tokenValue = auth["deviceToken"]?.value as? String {
            let role = auth["role"]?.value as? String ?? "operator"
            let scopes = (auth["scopes"]?.value as? [AnyCodable])?.compactMap { $0.value as? String } ?? []
            _ = tokenStore.storeToken(deviceId: identity.deviceId, role: role, token: tokenValue, scopes: scopes)
        }
    }

    public func request(method: String, payload: Data) async throws -> Data {
        let id = UUID().uuidString
        let paramsJson = (try? JSONSerialization.jsonObject(with: payload)) as? [String: Any] ?? [:]
        let frame = RequestFrame(type: "req", id: id, method: method, params: AnyCodable(paramsJson))
        try await socket.send(.data(try encoder.encode(frame)))
        let res = try await receiveResponse(id: id)
        guard res.ok, let payload = res.payload else {
            throw NSError(domain: "Gateway", code: 1, userInfo: [NSLocalizedDescriptionKey: "request failed"])
        }
        return try encoder.encode(payload)
    }

    private func receiveResponse(id: String) async throws -> ResponseFrame {
        while true {
            let msg = try await socket.receive()
            guard let data = decodeMessageData(msg) else { continue }
            let frame = try decoder.decode(GatewayFrame.self, from: data)
            if case let .res(res) = frame, res.id == id {
                return res
            }
        }
    }

    private func receiveChallenge() async -> String? {
        do {
            let msg = try await socket.receive()
            guard let data = decodeMessageData(msg) else { return nil }
            guard let frame = try? decoder.decode(GatewayFrame.self, from: data) else { return nil }
            if case let .event(evt) = frame, evt.event == "connect.challenge" {
                if let payload = evt.payload?.value as? [String: AnyCodable],
                   let nonce = payload["nonce"]?.value as? String { return nonce }
            }
        } catch {}
        return nil
    }

    private nonisolated func decodeMessageData(_ msg: URLSessionWebSocketTask.Message) -> Data? {
        switch msg {
        case let .data(data): return data
        case let .string(text): return Data(text.utf8)
        @unknown default: return nil
        }
    }
}
```

**Step 4: Re-run tests**

```bash
swift test --package-path Packages/OpenClawClientCore --filter GatewayConnectionTests
```
Expected: PASS.

**Step 5: Commit**

```bash
git add Packages/OpenClawClientCore/Sources/OpenClawClientCore/GatewayConnection.swift \
  Packages/OpenClawClientCore/Tests/OpenClawClientCoreTests/GatewayConnectionTests.swift
 git commit -m "feat: add gateway connection"
```

---

### Task 5: Chat message model + mapper (TDD)

**Files:**
- Create: `Packages/OpenClawClientCore/Sources/OpenClawClientCore/ChatMessage.swift`
- Create: `Packages/OpenClawClientCore/Sources/OpenClawClientCore/ChatMessageMapper.swift`
- Create: `Packages/OpenClawClientCore/Tests/OpenClawClientCoreTests/ChatMessageMapperTests.swift`

**Step 1: Write failing test** (`ChatMessageMapperTests.swift`)

```swift
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
```

**Step 2: Run test to verify it fails**

```bash
swift test --package-path Packages/OpenClawClientCore --filter ChatMessageMapperTests
```
Expected: FAIL (ChatMessage/ChatMessageMapper missing).

**Step 3: Write minimal implementation**

`ChatMessage.swift`:
```swift
import Foundation

public enum ChatRole: String, Sendable {
    case user
    case assistant
    case system
    case unknown
}

public enum ChatDeliveryState: Sendable {
    case sending
    case sent
    case failed
}

public struct ChatMessage: Identifiable, Sendable {
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
```

`ChatMessageMapper.swift`:
```swift
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
                guard let p = part.value as? [String: AnyCodable] else { return nil }
                guard (p["type"]?.value as? String) == "text" else { return nil }
                return p["text"]?.value as? String
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
```

**Step 4: Re-run tests**

```bash
swift test --package-path Packages/OpenClawClientCore --filter ChatMessageMapperTests
```
Expected: PASS.

**Step 5: Commit**

```bash
git add Packages/OpenClawClientCore/Sources/OpenClawClientCore/ChatMessage.swift \
  Packages/OpenClawClientCore/Sources/OpenClawClientCore/ChatMessageMapper.swift \
  Packages/OpenClawClientCore/Tests/OpenClawClientCoreTests/ChatMessageMapperTests.swift
 git commit -m "feat: add chat message mapper"
```

---

### Task 6: Chat view model (TDD)

**Files:**
- Create: `Packages/OpenClawClientCore/Sources/OpenClawClientCore/ChatViewModel.swift`
- Create: `Packages/OpenClawClientCore/Tests/OpenClawClientCoreTests/ChatViewModelTests.swift`

**Step 1: Write failing test** (`ChatViewModelTests.swift`)

```swift
import Foundation
import Testing
@testable import OpenClawClientCore

final class MockChatService: ChatServiceType {
    var historyResult: [ChatMessage] = []
    var sendResult: ChatSendResult = ChatSendResult(runId: "r1", status: "started")

    func history(sessionKey: String) async throws -> [ChatMessage] { historyResult }
    func send(sessionKey: String, message: String, thinking: String?, idempotencyKey: String) async throws -> ChatSendResult {
        sendResult
    }
    func abort(sessionKey: String, runId: String?) async throws {}
}

struct ChatViewModelTests {
    @Test func sendAppendsUserMessage() async throws {
        let chat = MockChatService()
        let vm = ChatViewModel(chat: chat)
        vm.inputText = "hi"
        try await vm.sendMessage()
        #expect(vm.messages.first?.text == "hi")
    }
}
```

**Step 2: Run test to verify it fails**

```bash
swift test --package-path Packages/OpenClawClientCore --filter ChatViewModelTests
```
Expected: FAIL (ChatViewModel missing).

**Step 3: Write minimal implementation** (`ChatViewModel.swift`)

```swift
import Foundation
import Observation

public struct ChatSendResult: Sendable {
    public let runId: String
    public let status: String
}

public protocol ChatServiceType: Sendable {
    func history(sessionKey: String) async throws -> [ChatMessage]
    func send(sessionKey: String, message: String, thinking: String?, idempotencyKey: String) async throws -> ChatSendResult
    func abort(sessionKey: String, runId: String?) async throws
}

@MainActor
@Observable
public final class ChatViewModel {
    public var messages: [ChatMessage] = []
    public var inputText: String = ""
    public var connectionState: String = "disconnected"
    public var errorMessage: String? = nil

    private let chat: ChatServiceType
    private let sessionKey = "main"

    public init(chat: ChatServiceType) {
        self.chat = chat
    }

    public func loadHistory() async throws {
        messages = try await chat.history(sessionKey: sessionKey)
    }

    public func sendMessage() async throws {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        let pending = ChatMessage(role: .user, text: text, state: .sending)
        messages.append(pending)
        let _ = try await chat.send(sessionKey: sessionKey, message: text, thinking: "low", idempotencyKey: UUID().uuidString)
        if let idx = messages.indices.last {
            messages[idx] = ChatMessage(id: messages[idx].id, role: .user, text: text, state: .sent)
        }
    }
}
```

**Step 4: Re-run tests**

```bash
swift test --package-path Packages/OpenClawClientCore --filter ChatViewModelTests
```
Expected: PASS.

**Step 5: Commit**

```bash
git add Packages/OpenClawClientCore/Sources/OpenClawClientCore/ChatViewModel.swift \
  Packages/OpenClawClientCore/Tests/OpenClawClientCoreTests/ChatViewModelTests.swift
 git commit -m "feat: add chat view model"
```

---

### Task 7: Wire SDK ChatService into core package (TDD)

**Files:**
- Create: `Packages/OpenClawClientCore/Sources/OpenClawClientCore/ChatServiceAdapter.swift`
- Create: `Packages/OpenClawClientCore/Tests/OpenClawClientCoreTests/ChatServiceAdapterTests.swift`

**Step 1: Write failing test** (`ChatServiceAdapterTests.swift`)

```swift
import Testing
import OpenClawProtocol
@testable import OpenClawClientCore

final class MockGateway: GatewayRequesting, @unchecked Sendable {
    var lastMethod: String?
    var lastPayload: Data?
    func request(method: String, payload: Data) async throws -> Data {
        lastMethod = method
        lastPayload = payload
        return try JSONEncoder().encode(ChatHistoryResponse(sessionKey: "main", sessionId: nil, messages: [], thinkingLevel: nil))
    }
}

struct ChatServiceAdapterTests {
    @Test func historyCallsChatHistory() async throws {
        let gateway = MockGateway()
        let adapter = ChatServiceAdapter(gateway: gateway)
        _ = try await adapter.history(sessionKey: "main")
        #expect(gateway.lastMethod == "chat.history")
    }
}
```

**Step 2: Run test to verify it fails**

```bash
swift test --package-path Packages/OpenClawClientCore --filter ChatServiceAdapterTests
```
Expected: FAIL (ChatServiceAdapter missing).

**Step 3: Write minimal implementation** (`ChatServiceAdapter.swift`)

```swift
import Foundation
import OpenClawSDK
import OpenClawProtocol

public struct ChatServiceAdapter: ChatServiceType, Sendable {
    private let service: ChatService

    public init(gateway: GatewayRequesting) {
        self.service = ChatService(gateway: gateway)
    }

    public func history(sessionKey: String) async throws -> [ChatMessage] {
        let res = try await service.history(sessionKey: sessionKey)
        return ChatMessageMapper.fromHistory(res.messages)
    }

    public func send(sessionKey: String, message: String, thinking: String?, idempotencyKey: String) async throws -> ChatSendResult {
        let res = try await service.send(sessionKey: sessionKey, message: message, thinking: thinking, idempotencyKey: idempotencyKey)
        return ChatSendResult(runId: res.runId, status: res.status)
    }

    public func abort(sessionKey: String, runId: String?) async throws {
        _ = try await service.abort(sessionKey: sessionKey, runId: runId)
    }
}
```

**Step 4: Re-run tests**

```bash
swift test --package-path Packages/OpenClawClientCore --filter ChatServiceAdapterTests
```
Expected: PASS.

**Step 5: Commit**

```bash
git add Packages/OpenClawClientCore/Sources/OpenClawClientCore/ChatServiceAdapter.swift \
  Packages/OpenClawClientCore/Tests/OpenClawClientCoreTests/ChatServiceAdapterTests.swift
 git commit -m "feat: add chat service adapter"
```

---

### Task 8: Build SwiftUI UI + settings sheet (manual + light code)

**Files:**
- Modify: `openclaw-ios/ContentView.swift`
- Modify: `openclaw-ios/openclaw_iosApp.swift`
- Create: `openclaw-ios/SettingsView.swift`

**Step 1: Add SettingsView** (`SettingsView.swift`)

```swift
import SwiftUI
import Observation
import OpenClawClientCore

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Gateway") {
                    TextField("ws://127.0.0.1:18789", text: $viewModel.gatewayUrl)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Token", text: $viewModel.gatewayToken)
                }
                Section {
                    Button("Save") { viewModel.save() }
                    Button("Clear Token", role: .destructive) { viewModel.clearToken() }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
```

**Step 2: Add simple SettingsViewModel** (append to `openclaw_iosApp.swift` or create `SettingsViewModel.swift`)

```swift
import Observation
import OpenClawClientCore

@MainActor
@Observable
final class SettingsViewModel {
    var gatewayUrl: String
    var gatewayToken: String
    private let store: SettingsStore

    init(store: SettingsStore) {
        self.store = store
        self.gatewayUrl = store.loadGatewayUrl() ?? ""
        self.gatewayToken = store.loadGatewayToken() ?? ""
    }

    func save() {
        store.saveGatewayUrl(gatewayUrl)
        if !gatewayToken.isEmpty {
            store.saveGatewayToken(gatewayToken)
        }
    }

    func clearToken() {
        gatewayToken = ""
        store.clearGatewayToken()
    }
}
```

**Step 3: Update ContentView**

```swift
import SwiftUI
import OpenClawClientCore

struct ContentView: View {
    @Bindable var chat: ChatViewModel
    @Bindable var settings: SettingsViewModel
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            VStack {
                if chat.messages.isEmpty {
                    Text("暂无消息")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 24)
                } else {
                    List(chat.messages) { message in
                        HStack(alignment: .top) {
                            Text(message.role.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 80, alignment: .leading)
                            Text(message.text)
                        }
                    }
                }

                HStack {
                    TextField("输入消息", text: $chat.inputText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("发送") {
                        Task { try? await chat.sendMessage() }
                    }
                }
                .padding()
            }
            .navigationTitle("OpenClaw")
            .toolbar {
                Button("设置") { showingSettings = true }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(viewModel: settings)
            }
            .task {
                try? await chat.loadHistory()
            }
        }
    }
}
```

**Step 4: Update App entry** (`openclaw_iosApp.swift`)

```swift
import SwiftUI
import OpenClawClientCore

@main
struct openclaw_iosApp: App {
    @State private var chat: ChatViewModel
    @State private var settings: SettingsViewModel

    init() {
        let secrets = KeychainSecretStore()
        let settingsStore = SettingsStore(secrets: secrets)
        let settingsVM = SettingsViewModel(store: settingsStore)

        let tokenStore = InMemoryTokenStore()
        let identityStore = DeviceIdentityStore()
        let url = URL(string: settingsVM.gatewayUrl.isEmpty ? "ws://127.0.0.1:18789" : settingsVM.gatewayUrl)!
        let connection = GatewayConnection(url: url, tokenStore: tokenStore, identityStore: identityStore)
        let chatService = ChatServiceAdapter(gateway: connection)
        let chatVM = ChatViewModel(chat: chatService)

        _settings = State(initialValue: settingsVM)
        _chat = State(initialValue: chatVM)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(chat: chat, settings: settings)
        }
    }
}
```

**Step 5: Manual check**
- Run app in Xcode
- 打开设置，填写 `ws://127.0.0.1:18789` 和 token
- 返回聊天页，发送消息并查看 history

**Step 6: Commit**

```bash
git add openclaw-ios/ContentView.swift \
  openclaw-ios/openclaw_iosApp.swift \
  openclaw-ios/SettingsView.swift
 git commit -m "feat: add chat UI"
```

---

## Verification
- Core tests:
  - `swift test --package-path Packages/OpenClawClientCore --filter SettingsStoreTests`
  - `swift test --package-path Packages/OpenClawClientCore --filter GatewayConnectionTests`
  - `swift test --package-path Packages/OpenClawClientCore --filter ChatMessageMapperTests`
  - `swift test --package-path Packages/OpenClawClientCore --filter ChatViewModelTests`
  - `swift test --package-path Packages/OpenClawClientCore --filter ChatServiceAdapterTests`

## Notes
- UI wiring uses @Observable + @Bindable to align with Observation guidance.
- GatewayConnection currently handles sequential requests; event stream and auto-reconnect are deferred.
