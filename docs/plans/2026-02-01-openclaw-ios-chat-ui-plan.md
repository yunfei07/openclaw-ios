# OpenClaw iOS Chat UI Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将聊天界面升级为“微信风”对话 UI（柔和圆润、信息清晰、阅读舒适）。

**Architecture:** 仅改 SwiftUI 视图层（ContentView + SettingsView），新增轻量 UI 组件与样式常量；不改变业务逻辑与数据流。

**Tech Stack:** Swift 6.2, SwiftUI, Observation.

---

### Task 1: 新增 Chat UI 样式与气泡组件

**Files:**
- Create: `openclaw-ios/ChatUIStyle.swift`
- Create: `openclaw-ios/ChatBubbleView.swift`

**Step 1: 写失败测试（如需 UI 测试）**
- UI 变更难以自动测试，需你确认是否接受“手动验证替代自动化测试”。

**Step 2: 实现最小样式常量**

```swift
import SwiftUI

enum ChatUIStyle {
    static let background = LinearGradient(
        colors: [Color(.systemGroupedBackground), Color(.secondarySystemBackground)],
        startPoint: .top,
        endPoint: .bottom
    )
    static let bubbleIncoming = Color(.systemBackground)
    static let bubbleOutgoing = Color(red: 0.91, green: 0.97, blue: 0.92)
    static let bubbleRadius: CGFloat = 20
    static let bubbleShadow = Color.black.opacity(0.04)
}
```

**Step 3: 添加气泡视图**

```swift
struct ChatBubbleView: View {
    let text: String
    let isOutgoing: Bool

    var body: some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.primary)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(isOutgoing ? ChatUIStyle.bubbleOutgoing : ChatUIStyle.bubbleIncoming)
            .clipShape(.rect(cornerRadius: ChatUIStyle.bubbleRadius))
            .shadow(color: ChatUIStyle.bubbleShadow, radius: 6, x: 0, y: 2)
    }
}
```

**Step 4: 人工验证**
- 预览/真机查看气泡圆角、阴影与颜色是否符合“微信风”。

**Step 5: Commit**

```bash
git add openclaw-ios/ChatUIStyle.swift openclaw-ios/ChatBubbleView.swift

git commit -m "UI: add chat style and bubble view"
```

---

### Task 2: 改造 ContentView（聊天界面）

**Files:**
- Modify: `openclaw-ios/ContentView.swift`

**Step 1: 写失败测试（如需 UI 测试）**
- 同 Task 1（需确认是否接受手动验证）。

**Step 2: 实现 UI 结构**
- List → ScrollView + LazyVStack
- 顶部状态条改为胶囊提示条
- 输入区改为胶囊输入框 + 圆形发送按钮
- 增加点击背景收起键盘

**Step 3: 人工验证**
- 消息左右对齐与气泡宽度正确
- 输入区高度与触控区域符合 44x44
- 空状态文案不突兀

**Step 4: Commit**

```bash
git add openclaw-ios/ContentView.swift

git commit -m "UI: refresh chat layout"
```

---

### Task 3: 改造 SettingsView（设置页）

**Files:**
- Modify: `openclaw-ios/SettingsView.swift`

**Step 1: 写失败测试（如需 UI 测试）**
- 同 Task 1（需确认是否接受手动验证）。

**Step 2: 实现卡片化表单**
- Form → ScrollView + Card
- 主按钮“保存并返回”填满宽度
- “清除 Token”按钮改为描边红

**Step 3: 人工验证**
- 卡片分组清晰
- 输入框对齐一致
- 操作按钮清晰易点击

**Step 4: Commit**

```bash
git add openclaw-ios/SettingsView.swift

git commit -m "UI: redesign settings view"
```

---

### Full verification

Run: `swift test --package-path Packages/OpenClawClientCore`
Expected: PASS
