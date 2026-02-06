# OpenClaw iOS Telegram-Style Chat (Local-Only) Design (2026-02-06)

## Scope
- Target: iOS client (`openclaw-ios`) only
- Backend: **no changes** to OpenClaw gateway/protocol
- Goal: Telegram-like chat UX for **message experience** + **local-only message actions**
- Constraints: gateway provides only `chat.history`, `chat.send`, `chat.abort`, `chat.inject`

## Non-Goals
- Server-side edit/delete/reply/forward
- Read receipts and server-confirmed delivery states
- Multi-device sync for local-only metadata

## Current Limitations (Gateway)
- No edit/delete/reply APIs
- No stable `messageId` in `chat.history`
- Attachments via `chat.send` are images only (base64)

## Design Summary
Implement Telegram-like UX **entirely in iOS** by extending local message metadata, merging history without losing local state, and rendering custom Telegram-style bubbles.

## Data Model (Local)
Extend `ChatMessage` with local-only metadata (all optional, Codable):
- `localId`: stable local identifier for persistence
- `replyTo`: compact summary (original sender + snippet)
- `forwardedFrom`: source label
- `isEdited`: Bool
- `localDeleted`: Bool
- `fingerprint`: stable hash for dedupe (role + createdAt + text)

### Stable Identity
- For remote history: compute `fingerprint` and derive `localId` from it
- For new local messages: generate UUID `localId`
- Use `localId` for UI identity, not `id` from backend

## History Merge (Priority = Merge)
### `loadCachedHistory()`
- If current `messages` empty: use cached
- Else merge cached + existing, preserving pending/failed and local metadata

### `loadHistory()`
- If remote empty: keep local
- If remote non-empty:
  - Preserve all local `state != .sent`
  - Preserve local `createdAt` newer than max remote date
  - Merge by `fingerprint` to avoid duplicates
  - Prefer local version if it has local-only metadata

### Ordering
- Sort by `createdAt` ascending after merge
- Keep stable order for equal timestamps by `localId`

## UI Architecture
Keep `ExyteChat.ChatView` for list + input.
Replace bubble rendering with custom `TelegramBubbleView` (or `messageBuilder` hooks if available).

### Bubble Content
- Header: optional `Forwarded from …`
- Reply quote bar: left colored bar + sender + snippet
- Body text
- Footer: `edited` label, timestamp, status icon

### Status Icons (Local)
- `.sending` -> clock/spinner
- `.sent` -> single check
- `.failed` -> red exclamation + retry action

### Grouping Rules
- Consecutive same-role messages within 2 minutes are grouped
- Only last in group shows tail
- Avatar shown only for first incoming in group

## Local Actions
- Reply: long-press -> set reply context; send stores `replyTo`
- Forward: long-press -> set `forwardedFrom` and editable draft
- Edit: allowed for local pending/failed only
- Delete: local-only; show “Message deleted” placeholder

## Error Handling
- Send failure keeps message in list with retry button
- Merge logic prevents local-only metadata loss on reconnect

## Testing
- Unit tests: `ChatViewModel` merge rules, pending preservation, dedupe
- Manual UI: grouping, reply/forward, edit/delete, retry, immediate display while connecting

## Rollout Plan
1. Update model + merge logic in `OpenClawClientCore`
2. Add Telegram-style bubble + grouping UI
3. Add reply/forward/edit/delete local actions
4. Manual verification

