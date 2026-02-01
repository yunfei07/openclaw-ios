# OpenClaw iOS Chat Streaming Design (2026-02-01)

## 目标
在 openclaw-ios 上实现单连接 WebSocket 的实时 chat 事件流：发送后可边生成边展示助手回复，同时不影响现有 request/response RPC。

## 范围
- iOS 18+，Swift 6.2
- 仅支持单会话（sessionKey = main）
- 保留 chat.history / chat.send / chat.abort
- 不引入多会话列表与自动配对流程

## 方案选择
采用方案 1：单连接多路复用。
- GatewayConnection 维护常驻接收循环
- RPC 响应与事件流在同一连接上并行处理

## 架构与数据流
1. connect 成功后启动 receive loop
2. request 发送时登记 pendingRequests（id -> continuation）
3. 收到 res 帧：按 id 唤醒对应请求
4. 收到 event 帧（chat）：转发给 ChatEventStream
5. ChatViewModel 订阅事件流并增量更新消息

## 组件与接口变更
- GatewayConnection
  - 新增 startReceiveLoop
  - 维护 pendingRequests + eventStream
- ChatServiceAdapter
  - 新增 events() -> AsyncStream<ChatEvent>
- ChatViewModel
  - 新增 startStreaming()
  - 维护 activeRuns，按 runId 合并 delta/final

## 错误与边界处理
- WebSocket 断开：终止事件流，标记连接失败
- request 超时：移除 pendingRequests，返回错误
- 事件乱序：忽略更旧 seq，避免 UI 回退
- sessionKey 不匹配：忽略
- reconnect：拉取 history 重建状态

## 测试策略
- GatewayConnection：mock WebSocket，验证 res 分发与事件转发
- ChatServiceAdapter：验证 chat 事件映射
- ChatViewModel：delta/final/error 合并与状态更新

## 验收标准
- 发送后立即显示用户消息
- 助手回复逐字增长，final 后标记 sent
- 断线与错误能提示且不崩溃
- 重新连接后 history 恢复完整消息

## 非目标
- 多会话列表与切换
- 自动重连策略优化
- 端侧缓存与全文检索
