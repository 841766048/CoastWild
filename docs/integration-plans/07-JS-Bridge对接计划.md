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

- [ ] 先写所有 topic 的正常和错误 payload 解码测试。
- [ ] 实现 enum、Codable payload 和精确错误。

### Task 2: 路由和生命周期

**Files:** Create `BridgeRouter.swift`, `BridgeEventEmitter.swift`; Test `BridgeTests.swift`.

- [ ] 先写每个 topic 只调用指定 handler 的测试。
- [ ] 实现路由、`AppLifecycleState` 和 `KeyboardInset` 事件。
- [ ] 验证 observer 在 controller 释放后被移除。

### Task 3: Native 回调

**Files:** Create `JavaScriptCallbackEncoder.swift`; Modify `BusinessWebController.swift`; Test `BridgeTests.swift`.

- [ ] 先写反斜杠、引号、换行和 Unicode 的回调转义测试。
- [ ] 实现背景登录、IAP 日志、价格、内部页状态回调。

