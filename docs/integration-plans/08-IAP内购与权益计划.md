# IAP 内购与权益 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现 StoreKit 2 购买、服务端验单、权益同步和未完成交易恢复。

**Architecture:** `PurchaseCoordinator` 协调 Product API、服务端订单和交易更新；权益只由服务端验单结果激活。

**Tech Stack:** StoreKit 2、Swift Concurrency、XCTest、StoreKit Configuration。

## Global Constraints

- SKU 必须来自正式商品清单。
- 验单成功前不发放权益。
- 支付页展示价格、周期、自动续订、权益、恢复购买、协议和隐私。

---

### Task 1: 商品与价格

**Files:** Create `Integration/Purchase/ProductCatalog.swift`; Test `Tests/PurchaseTests.swift`.

- [x] 先写多 SKU、缺失 SKU、本地化价格和币种测试。
- [x] 实现 Product 查询与 Bridge 价格 DTO；正式 SKU 尚未配置，真实商品查询待上线门禁验证。

### Task 2: 购买和验单

**Files:** Create `PurchaseCoordinator.swift`, `PurchaseLog.swift`; Test `PurchaseTests.swift`.

- [x] 先写建单失败、取消、pending、unverified、验单失败和成功测试。
- [x] 实现建单→购买→本地验证→服务端验单→finish 顺序。
- [x] 生成结构化、不含收据全文的 IAP 日志。
- [x] StoreKit 订单映射覆盖 pending 保留，用户取消与 `product.purchase()` 抛错清理，立即验证成功关联交易后清理；由适配器聚焦代码审查及模拟器编译验证。

### Task 3: 恢复与权益

**Files:** Create `EntitlementStore.swift`; Modify `UI/ProfileController.swift`; Test `PurchaseTests.swift`, `UITests/CoastWildUITests.swift`.

- [x] 先写 App 启动交易更新、多笔并发验单和恢复购买测试。
- [x] 实现恢复入口、进度、可重试错误和权益刷新；沙盒/正式交易仍需 App Store Connect 商品与服务端联调。
- [x] 回归覆盖延迟交易更新迁移 pending 映射，以及恢复时对每笔已验证 entitlement 均发送服务端；无本地 order ID 仍传递 `nil`、激活权益并 finish。

### Task 4: JS Bridge 接入

- [x] 使用独立 `IAPBridgeHandler` 接入商品价格查询、购买、IAP 日志和并发购买保护。
- [x] 通过现有安全编码器回调 `getProductPriceResult` 与 `iapLog`，不向 JS 暴露收据或原始错误。
