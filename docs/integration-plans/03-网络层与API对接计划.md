# 网络层与 API 对接 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 提供六个加密 POST API 及统一请求字段、重试和错误模型。

**Architecture:** `IntegrationAPIClient` 依赖可替换的 `HTTPTransport`、`IntegrationCipher` 和 `RequestContextProvider`，测试不访问真实网络。

**Tech Stack:** URLSession、Swift Concurrency、XCTest。

## Global Constraints

- `http_headers` 是加密 JSON body 的子字典，不是 HTTP Header。
- 总尝试次数为 3，加密参数错误不重试。
- `getConfig` 使用 configKey，其他接口使用 enKey。

---

### Task 1: 传输与错误协议

**Files:** Create `CoastWild/Core/HTTPTransport.swift`, `CoastWild/Core/IntegrationAPIError.swift`; Test `Tests/IntegrationNetworkTests.swift`.

- [x] 先写 URLRequest 传递和 HTTP 状态码映射测试。
- [x] 实现 `URLSessionTransport.send(_:) async throws -> HTTPTransportResponse`。
- [x] 覆盖超时、无网络、非 2xx 和空响应。

### Task 2: 公共请求上下文

**Files:** Create `CoastWild/Core/RequestContext.swift`; Test `Tests/IntegrationNetworkTests.swift`.

- [x] 写 16+ 个固定/条件字段测试，时区、Locale 和设备值通过依赖注入固定。
- [x] 实现 `RequestContextProvider.headers(session:)` 和 OAuth 风控参数。
- [x] 验证 H5 注入和 Native API 可复用同一份字典。

### Task 3: 六个 API

**Files:** Create `CoastWild/Core/IntegrationAPIClient.swift`, `CoastWild/Core/IntegrationDTOs.swift`; reuse `IntegrationEndpointPaths.swift`; Test `Tests/IntegrationNetworkTests.swift`.

- [x] 先为每个端点写 URL、参数、密钥选择和 DTO 解码测试。
- [x] 实现 `getConfig`、`getStrategy`、`oauth`、`createRecharge`、`verifyReceipt`、`submitAttribution`。
- [x] 写前两次失败、第三次成功以及三次失败的重试测试。
- [x] 运行 `swift test --filter IntegrationNetworkTests` 和全量测试。
