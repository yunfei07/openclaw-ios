# OpenClaw iOS Chat Streaming Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在 iOS 端通过单 WebSocket 事件流实现 chat 流式回复展示。

**Architecture:** GatewayConnection 启动常驻 receive loop，用 pendingRequests 分发 RPC 响应，用 AsyncStream 转发 event；ChatServiceAdapter 映射 chat event 为 ChatEvent；ChatViewModel 订阅事件并增量更新消息。

**Tech Stack:** Swift 6.2, SwiftUI, AsyncStream, OpenClawProtocol, Swift Testing.

---

### Task 1: ChatEvent 模型与映射器

**Files:**
- Create: `Packages/OpenClawClientCore/Sources/OpenClawClientCore/ChatEvent.swift`
- Create: `Packages/OpenClawClientCore/Sources/OpenClawClientCore/ChatEventMapper.swift`
- Test: `Packages/OpenClawClientCore/Tests/OpenClawClientCoreTests/ChatEventMapperTests.swift`

**Step 1: Write the failing test**

```swift
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
```

**Step 2: Run test to verify it fails**

Run: `swift test --package-path Packages/OpenClawClientCore --filter ChatEventMapperTests`
Expected: FAIL (ChatEventMapper 未实现)

**Step 3: Write minimal implementation**

```swift
public enum ChatEventState: String, Sendable { case delta, final, error, unknown }

public struct ChatEvent: Sendable {
    public let runId: String
    public let sessionKey: String
    public let seq: Int?
    public let state: ChatEventState
    public let message: ChatMessage?
    public let errorMessage: String?
}
```

```swift
public enum ChatEventMapper {
    public static func from(event: EventFrame) -> ChatEvent? {
        guard event.event == "chat" else { return nil }
        guard let payload = event.payload?.value as? [String: AnyCodable] else { return nil }
        guard let runId = payload["runId"]?.value as? String,
              let sessionKey = payload["sessionKey"]?.value as? String else { return nil }
        let seq = payload["seq"]?.value as? Int
        let stateRaw = payload["state"]?.value as? String
        let state = ChatEventState(rawValue: stateRaw ?? "") ?? .unknown
        let errorMessage = payload["errorMessage"]?.value as? String
        let message = payload["message"].flatMap { ChatMessageMapper.fromHistory([$0]).first }
        return ChatEvent(runId: runId, sessionKey: sessionKey, seq: seq, state: state, message: message, errorMessage: errorMessage)
    }
}
```

**Step 4: Run test to verify it passes**

Run: `swift test --package-path Packages/OpenClawClientCore --filter ChatEventMapperTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Packages/OpenClawClientCore/Sources/OpenClawClientCore/ChatEvent.swift \
        Packages/OpenClawClientCore/Sources/OpenClawClientCore/ChatEventMapper.swift \
        Packages/OpenClawClientCore/Tests/OpenClawClientCoreTests/ChatEventMapperTests.swift

git commit -m "Core: add chat event mapping"
```

---

### Task 2: GatewayConnection 事件流 + 响应分发

**Files:**
- Modify: `Packages/OpenClawClientCore/Sources/OpenClawClientCore/GatewayConnection.swift`
- Modify: `Packages/OpenClawClientCore/Tests/OpenClawClientCoreTests/GatewayConnectionTests.swift`

**Step 1: Write the failing tests**

```swift
@Test func eventStreamEmitsChatEvent() async throws {
    let socket = MockWebSocket()
    let tokenStore = RecordingTokenStore()
    let identityStore = DeviceIdentityStore(rootURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    let conn = GatewayConnection(url: URL(string: "ws://127.0.0.1:18789")!, tokenStore: tokenStore, identityStore: identityStore, socket: socket)

    let payload: [String: AnyCodable] = ["runId": AnyCodable("run-1"), "sessionKey": AnyCodable("main"), "state": AnyCodable("delta")]
    let evt = GatewayFrame.event(EventFrame(type: "event", event: "chat", payload: AnyCodable(payload), seq: 1, stateversion: nil))
    socket.inbound.append(.data(try JSONEncoder().encode(evt)))

    let stream = await conn.events()
    var iterator = stream.makeAsyncIterator()
    let next = await iterator.next()
    #expect(next?.event == "chat")
}

@Test func requestReturnsEvenWhenEventArrivesFirst() async throws {
    let socket = MockWebSocket()
    let tokenStore = RecordingTokenStore()
    let identityStore = DeviceIdentityStore(rootURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    let conn = GatewayConnection(url: URL(string: "ws://127.0.0.1:18789")!, tokenStore: tokenStore, identityStore: identityStore, socket: socket)

    let eventFrame = GatewayFrame.event(EventFrame(type: "event", event: "chat", payload: AnyCodable(["runId": AnyCodable("run-1"), "sessionKey": AnyCodable("main")]), seq: 1, stateversion: nil))
    let resFrame = GatewayFrame.res(ResponseFrame(type: "res", id: "req-1", ok: true, payload: AnyCodable(["ok": AnyCodable(true)]), error: nil))
    socket.inbound = [.data(try JSONEncoder().encode(eventFrame)), .data(try JSONEncoder().encode(resFrame))]

    let result = try await conn.request(method: "health", payload: Data(), id: "req-1")
    let decoded = try JSONDecoder().decode(AnyCodable.self, from: result)
    #expect(decoded.value as? [String: AnyCodable] != nil)
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test --package-path Packages/OpenClawClientCore --filter GatewayConnectionTests`
Expected: FAIL (events() 与 request(id:) 未实现)

**Step 3: Write minimal implementation**

- 增加 `events()` 返回 AsyncStream<EventFrame>
- 引入 `pendingRequests: [String: CheckedContinuation<ResponseFrame, Error>]`
- 新增 `startReceiveLoopIfNeeded()` 并在 connect/request 前调用
- receive loop 内部：
  - `res` 帧 → 恢复 continuation
  - `event` 帧 → continuation.yield(event)

**Step 4: Run tests to verify they pass**

Run: `swift test --package-path Packages/OpenClawClientCore --filter GatewayConnectionTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Packages/OpenClawClientCore/Sources/OpenClawClientCore/GatewayConnection.swift \
        Packages/OpenClawClientCore/Tests/OpenClawClientCoreTests/GatewayConnectionTests.swift

git commit -m "Core: stream gateway events"
```

---

### Task 3: ChatServiceAdapter 暴露事件流

**Files:**
- Modify: `Packages/OpenClawClientCore/Sources/OpenClawClientCore/ChatViewModel.swift` (更新 ChatServiceType)
- Modify: `Packages/OpenClawClientCore/Sources/OpenClawClientCore/ChatServiceAdapter.swift`
- Modify: `Packages/OpenClawClientCore/Tests/OpenClawClientCoreTests/ChatServiceAdapterTests.swift`

**Step 1: Write failing test**

```swift
@Test func eventsMapChatPayload() async throws {
    let gateway = MockGateway(events: [
        EventFrame(type: "event", event: "chat", payload: AnyCodable(["runId": AnyCodable("run-1"), "sessionKey": AnyCodable("main"), "state": AnyCodable("delta")]), seq: 1, stateversion: nil)
    ])
    let adapter = ChatServiceAdapter(gateway: gateway)
    var iterator = adapter.events().makeAsyncIterator()
    let evt = await iterator.next()
    #expect(evt?.runId == "run-1")
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --package-path Packages/OpenClawClientCore --filter ChatServiceAdapterTests`
Expected: FAIL (events() 未实现)

**Step 3: Write minimal implementation**

- 新增 `GatewayEventStreaming` 协议：`func events() -> AsyncStream<EventFrame>`
- `ChatServiceAdapter` 依赖 `GatewayRequesting & GatewayEventStreaming`
- `ChatServiceType` 增加 `events() -> AsyncStream<ChatEvent>`
- `ChatServiceAdapter.events()`：`gateway.events().compactMap(ChatEventMapper.from)`

**Step 4: Run test to verify it passes**

Run: `swift test --package-path Packages/OpenClawClientCore --filter ChatServiceAdapterTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Packages/OpenClawClientCore/Sources/OpenClawClientCore/ChatServiceAdapter.swift \
        Packages/OpenClawClientCore/Sources/OpenClawClientCore/ChatViewModel.swift \
        Packages/OpenClawClientCore/Tests/OpenClawClientCoreTests/ChatServiceAdapterTests.swift

git commit -m "Core: expose chat event stream"
```

---

### Task 4: ChatViewModel 流式合并与状态

**Files:**
- Modify: `Packages/OpenClawClientCore/Sources/OpenClawClientCore/ChatViewModel.swift`
- Modify: `Packages/OpenClawClientCore/Tests/OpenClawClientCoreTests/ChatViewModelTests.swift`

**Step 1: Write failing tests**

```swift
@Test func streamingUpdatesAssistantMessage() async throws {
    let chat = MockChatService()
    let vm = ChatViewModel(chat: chat)
    vm.startStreaming()

    chat.emit(ChatEvent(runId: "run-1", sessionKey: "main", seq: 1, state: .delta, message: ChatMessage(role: .assistant, text: "Hel", state: .sending), errorMessage: nil))
    chat.emit(ChatEvent(runId: "run-1", sessionKey: "main", seq: 2, state: .final, message: ChatMessage(role: .assistant, text: "Hello", state: .sent), errorMessage: nil))

    #expect(vm.messages.last?.text == "Hello")
    #expect(vm.messages.last?.state == .sent)
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test --package-path Packages/OpenClawClientCore --filter ChatViewModelTests`
Expected: FAIL (startStreaming/merge 未实现)

**Step 3: Write minimal implementation**

- 增加 `startStreaming()`：订阅 `chat.events()` 并调用 `handle(event:)`
- 增加 `activeRuns: [String: Int]`
- `sendMessage()`：发送成功后创建助手占位消息并记录 runId
- `handle(event:)`：
  - delta: 更新对应消息文本（若 newText 以 oldText 开头则替换，否则追加）
  - final: 更新文本并标记 sent，移除 activeRuns
  - error: 标记 failed，写入 errorMessage

**Step 4: Run tests to verify they pass**

Run: `swift test --package-path Packages/OpenClawClientCore --filter ChatViewModelTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Packages/OpenClawClientCore/Sources/OpenClawClientCore/ChatViewModel.swift \
        Packages/OpenClawClientCore/Tests/OpenClawClientCoreTests/ChatViewModelTests.swift

git commit -m "Core: stream chat updates"
```

---

### Task 5: App 集成事件流

**Files:**
- Modify: `openclaw-ios/openclaw_iosApp.swift`

**Step 1: Write failing test**

(无 UI 测试；此任务通过手工验证)

**Step 2: Implement minimal change**

- connect 成功后调用 `chatVM.startStreaming()`

**Step 3: Manual verification**

- 真机发送消息 → 助手消息逐字增长
- 断网 → 状态变为 failed

**Step 4: Commit**

```bash
git add openclaw-ios/openclaw_iosApp.swift

git commit -m "App: start chat streaming after connect"
```

---

### Full verification (after all tasks)

Run: `swift test --package-path Packages/OpenClawClientCore`
Expected: PASS
