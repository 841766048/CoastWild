# JS Bridge 对接 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现类型安全、来源受限、可测试的 H5/Native 双向通信。

**Architecture:** `BridgeRouter` 将 19 个 topic 解析为 enum 和 Codable payload；具体能力通过 handler 协议注入，JS 回调由一个序列化器生成。

**Tech Stack:** WebKit、Swift Codable、XCTest。

## Global Constraints

- 只接受已登记 host/frame 的消息。
- URL、SKU、金额、货币和布尔值全部做严格解析。
- `onCreateOrder` 在 H5 合同确认前作为显式 unsupported，不静默吞掉。

---

### Task 1: 协议模型

**Files:** Create `Integration/Bridge/BridgeMessage.swift`, `BridgePayloads.swift`; Test `Tests/BridgeTests.swift`.

- [x] 先写所有 topic 的正常和错误 payload 解码测试。
- [x] 实现 enum、类型化 payload 和精确错误。

### Task 2: 路由和生命周期

**Files:** Create `BridgeRouter.swift`, `BridgeEventEmitter.swift`; Test `BridgeTests.swift`.

- [x] 先写每个 topic 只产生一个指定类型消息的测试。
- [x] 实现路由、`AppLifecycleState` 和 `KeyboardInset` 事件。
- [x] 验证 observer 在 controller 释放后被移除。

### Task 3: Native 回调

**Files:** Create `JavaScriptCallbackEncoder.swift`; Modify `BusinessWebController.swift`; Test `BridgeTests.swift`.

- [x] 先写反斜杠、引号、换行和 Unicode 的回调转义测试。
- [x] 实现背景登录、IAP 日志、价格、内部页状态回调。

### Task 4: 业务动作接线（2026-09-22）

- [x] `BackgroundLogin` 执行 config → OAuth → strategy；strategy 成功后才提交新 session，失败保留当前 session 并允许重试。
- [x] 后台登录并发请求去重；退出使正在进行的设备登录失效，防止旧请求恢复登录状态。
- [x] 使用最新 session、strategy、runtime 构建安全编码的 `backgroundLoginSuccess`，保留当前 controller、WKWebView 和历史记录，并更新后续导航注入脚本。
- [x] `Logout` 复用现有退出流程；`UpdateCoins` 调用权益恢复，不写入虚构余额。
- [x] `UpdateLanguage` 归一化并持久化后刷新当前根 H5 与本地键盘文案；`NativeLog` 只消费已脱敏 action。
- [x] `DidMoveToMainPage`、浏览器/外链、设置、评分、边缘手势与 VIP/充值回调由 WebView 执行既有动作规划。
- [x] Foundation 单测与 iOS Simulator workspace 构建通过。
- [ ] 使用真实 H5 与后台服务核验全部 topic、后台登录回调字段、失败重试和语言切换效果。
- [ ] 在设备核验 Safari、系统设置、评分 UI 及真实 StoreKit 权益同步；`onCreateOrder` 继续注册但不执行。

提交边界：应用入口接线依赖当前工作树已有、尚未提交的 `remoteAuthenticated(session:strategy:)` 与 `BusinessWebEntry` 改动；本任务不代为提交这些既有改动。
