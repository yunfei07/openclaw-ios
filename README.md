# OpenClaw iOS

OpenClaw native iOS client powered by ExyteChat UI and OpenClaw Gateway.

Chinese README: `README.zh-CN.md`

## Overview

- Connect to OpenClaw Gateway (WebSocket) and chat in real time
- Modern chat UI (bubbles, input bar, timestamps)
- Attachment / voice / sticker entry points reserved (not implemented yet)
- Local chat history cache (persists across app restarts)
- Settings screen for Gateway URL and Token

## Requirements

- iOS 26.2 (current Xcode project deployment target; adjustable in Xcode)
- Open and run `openclaw-ios.xcodeproj` with Xcode

## Quick Start

1. Open `openclaw-ios.xcodeproj` in Xcode
2. Run the `openclaw-ios` target on a device or simulator
3. Tap “设置” (Settings) in the top-right corner
4. Fill in Gateway URL and Token, then save
5. The app connects automatically and starts chatting

## Gateway Configuration

- **Gateway URL** (WebSocket), for example:

```text
ws://<gateway-host>:18789
```

- **Token (optional)**:
  - With Token: connect via shared token
  - Without Token: connect with device identity (requires pairing approval)

## Local Chat History

- Loads cached history on launch
- After connecting, it fetches remote history; if local cache is empty, it uses remote history

## Troubleshooting

### Connection failed

- Ensure the phone can reach the gateway (same LAN or reachable network)
- For `ws://`, add an ATS exception in `Config/Info.plist` for your gateway host/IP (or use `wss://`)
- If Token is empty, make sure the gateway approves pairing for the device

## Project Structure

- `openclaw-ios/`: iOS app sources
- `Packages/OpenClawClientCore/`: shared core logic (messages, connection, cache)
- `Config/Info.plist`: app configuration (local network + ATS)

## Dependencies

- OpenClaw SDK (Swift Package)
- ExyteChat (Swift Package)
