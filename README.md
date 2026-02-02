# OpenClaw iOS

English | 中文

OpenClaw native iOS client powered by ExyteChat UI and OpenClaw Gateway.

## English

### Overview

- Connect to OpenClaw Gateway (WebSocket) and chat in real time
- Modern chat UI (bubbles, input bar, timestamps)
- Attachment / voice / sticker entry points reserved (not implemented yet)
- Local chat history cache (persists across app restarts)
- Settings screen for Gateway URL and Token

### Requirements

- iOS 26.2 (current Xcode project deployment target; adjustable in Xcode)
- Open and run `openclaw-ios.xcodeproj` with Xcode

### Quick Start

1. Open `openclaw-ios.xcodeproj` in Xcode
2. Run the `openclaw-ios` target on a device or simulator
3. Tap “设置” (Settings) in the top-right corner
4. Fill in Gateway URL and Token, then save
5. The app connects automatically and starts chatting

### Gateway Configuration

- **Gateway URL** (WebSocket), for example:

```text
ws://<gateway-host>:18789
```

- **Token (optional)**:
  - With Token: connect via shared token
  - Without Token: connect with device identity (requires pairing approval)

### Local Chat History

- Loads cached history on launch
- After connecting, it fetches remote history; if local cache is empty, it uses remote history

### Troubleshooting

#### Connection failed

- Ensure the phone can reach the gateway (same LAN or reachable network)
- For `ws://`, add an ATS exception in `Config/Info.plist` for your gateway host/IP (or use `wss://`)
- If Token is empty, make sure the gateway approves pairing for the device

### Project Structure

- `openclaw-ios/`: iOS app sources
- `Packages/OpenClawClientCore/`: shared core logic (messages, connection, cache)
- `Config/Info.plist`: app configuration (local network + ATS)

### Dependencies

- OpenClaw SDK (Swift Package)
- ExyteChat (Swift Package)

## 中文

### 功能概览

- 连接 OpenClaw Gateway（WebSocket）并进行实时对话
- 现代化聊天 UI（气泡、输入框、时间等）
- 预留附件 / 语音 / 贴纸入口（暂不实现功能）
- 本地缓存聊天记录（App 重启后可恢复）
- 设置页管理 Gateway 地址与 Token

### 运行环境

- iOS 26.2（当前 Xcode 工程默认部署目标，可在 Xcode 中调整）
- 使用 Xcode 打开并运行 `openclaw-ios.xcodeproj`

### 快速开始

1. 使用 Xcode 打开 `openclaw-ios.xcodeproj`
2. 选择 `openclaw-ios` target，运行到真机或模拟器
3. 点击右上角“设置”进入配置页
4. 填写 Gateway 地址与 Token，保存后回到聊天页
5. App 会自动连接网关并开始对话

### Gateway 配置

- **Gateway 地址**：WebSocket 地址，例如：

```text
ws://<gateway-host>:18789
```

- **Token（可选）**：
  - 填写 Token：使用共享 Token 直接连接
  - 留空 Token：使用设备身份连接（需要网关侧批准配对）

### 本地聊天记录

- App 启动时会先加载本地缓存的聊天记录
- 连接网关后拉取历史记录；若本地为空且网关有历史，会使用网关历史

### 常见问题

#### 连接失败

- 确认手机与网关在同一网络或可达
- 使用 `ws://` 时，需在 `Config/Info.plist` 的 `NSAppTransportSecurity` 中为你的网关域名/IP 添加例外（或改用 `wss://`）
- 若未填写 Token，请确认网关允许该设备完成配对

### 目录结构

- `openclaw-ios/`：iOS App 代码
- `Packages/OpenClawClientCore/`：共享核心逻辑（消息、连接、缓存）
- `Config/Info.plist`：App 配置（含本地网络与 ATS 配置）

### 依赖

- OpenClaw SDK（Swift Package）
- ExyteChat（Swift Package）
