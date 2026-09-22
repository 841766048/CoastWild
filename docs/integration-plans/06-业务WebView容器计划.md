# 业务 WebView 容器 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 创建与本地学习 WebView 隔离的远程业务 H5 容器。

**Architecture:** `BusinessWebController` 拥有专用 `WKWebViewConfiguration`、受控导航和注入生成器；不与 `LearningWebController` 共享消息处理器。

**Tech Stack:** WebKit、UIKit、XCTest。

## Global Constraints

- 只加载经配置验证的 HTTPS host。
- JavaScript 在 document start 注入到所有 frame。
- 摄像头/麦克风权限不得超越 Info.plist 和用户授权。

---

### Task 1: 注入数据生成

**Files:** Create `Integration/Web/BusinessWebBootstrap.swift`; Test `Tests/BusinessWebTests.swift`.

- [x] 先写 `appConfigOptions`、`webLoadTime`、`safeAreaInsets`、`appIconBase64` 的序列化和 JS 转义测试。
- [x] 实现纯函数生成器，不拼接未转义的用户数据。

### Task 2: 主容器

**Files:** Create `BusinessWebController.swift`, `BusinessWebNavigationPolicy.swift`; Test `BusinessWebTests.swift`.

- [x] 先写 HTTPS 白名单、外部 scheme 和拒绝未知 scheme 的策略测试。
- [x] 实现 WebView 配置、加载进度、失败重试和内容进程恢复。

### Task 3: 二级容器

**Files:** Create `InternalWebController.swift`; Test `BusinessWebTests.swift`.

- [x] 验证独立 WebView 配置、只注册关闭消息、显隐状态回调；最低 iOS 17 中 `WKProcessPool` 已弃用且多实例不再有效，因此不调用该无效 API。
- [x] 实现导航栏显隐、标题和系统返回手势协调。
