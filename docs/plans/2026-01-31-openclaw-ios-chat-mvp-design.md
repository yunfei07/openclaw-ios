# OpenClaw iOS Chat MVP Design (2026-01-31)

## 目标
在 openclaw-ios 中实现最小可用的聊天体验：手动配置网关 URL 与 token，完成 connect 握手，并支持 chat.history / chat.send / chat.abort。

## 适用范围
- iOS 18+，Swift 6.2
- SwiftUI 单屏 + 设置弹窗
- 不包含自动重连、事件流订阅、多会话管理

## 方案选择
采用方案 1：单屏聊天 + 设置弹窗（sheet）。
- 优点：实现快、心智模型简单，满足 MVP 目标
- 缺点：后续扩展需要增加更多页面或状态

## 页面结构
- Chat 主页面：消息列表、输入框、发送按钮、连接状态提示
- Settings 弹窗：网关 URL、token 输入与保存/清除
- 启动行为：读取本地配置 → 若齐全则尝试连接 → 失败时保留离线状态

## 架构组件
- SettingsStore：持久化 `gatewayUrl` + token（URL: UserDefaults，token: Keychain）
- GatewayConnection：WebSocket 连接与 request/response 路由
- ChatViewModel：UI 状态、消息列表、发送流程

## 数据流
1. App 启动读取 SettingsStore
2. 具备 URL/Token 则建立 WebSocket 并 connect
3. ChatViewModel 使用 ChatService 发送 history/send/abort
4. GatewayConnection 通过 RequestFrame/ResponseFrame 以 `id` 匹配返回

## 错误处理与体验
- 连接失败：状态提示 + 重试入口
- 发送失败：保留本地消息并标记失败，可重试
- 未配置：空状态引导用户打开设置
- Debug 日志仅输出连接与请求信息，不打印 token

## 测试策略
- 单元测试：SettingsStore、ChatViewModel 状态机、GatewayConnection request 路由
- Mock WebSocket：验证 request/response 匹配逻辑
- 手工验证：本机 Gateway（`ws://127.0.0.1:18789`）全流程测试

## 非目标
- 自动重连/事件流
- 多会话列表
- 配对与导入流程
