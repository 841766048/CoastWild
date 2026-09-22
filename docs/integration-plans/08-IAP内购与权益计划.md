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
- [x] StoreKit 订单映射覆盖 pending 保留；首次拥有映射的购买在取消/抛错后清理匹配的 pending，重试取消/抛错保留原映射；验证成功关联有效订单号后仅清理匹配的 pending。Foundation 映射回归测试覆盖归属与清理，适配器经过聚焦代码审查及模拟器编译验证。
- [x] 同 SKU 已有非空 pending 订单时，`prepareAttempt` 复用原订单号并标记为非拥有者，仍允许调用 `product.purchase()`，避免 Ask to Buy 拒绝或崩溃遗留状态永久锁住购买。重试保持 pending 时继续保留首单；验证成功以首单关联交易，协调器优先使用交易的订单号验单，之后新订单可正常开始。低层 `stage` 仍不覆盖已有映射。

### Task 3: 恢复与权益

**Files:** Create `EntitlementStore.swift`; Modify `UI/ProfileController.swift`; Test `PurchaseTests.swift`, `UITests/CoastWildUITests.swift`.

- [x] 先写 App 启动交易更新、多笔并发验单和恢复购买测试。
- [x] 实现恢复入口、进度、可重试错误和权益刷新；沙盒/正式交易仍需 App Store Connect 商品与服务端联调。
- [x] 回归覆盖延迟交易更新迁移 pending 映射，以及恢复时对每笔已验证 entitlement 均发送服务端；无本地 order ID 仍传递 `nil`、激活权益并 finish。
- [x] 监听从启动入口迁到配置/登录完成后的 `remoteAuthenticated`，保留单任务保护；先重放 `Transaction.unfinished` 再消费 `Transaction.updates`，两者共用验证、映射解析和投递逻辑。无映射交易不投递、不 finish；验单失败保留交易映射与未完成交易供后续认证登录重试（包括同进程登出后重新登录）。
- [x] 登出开始时先取消监听并将任务置空，再清理远程会话；账号删除仅在服务成功返回后停止监听，远程/本地删除失败仍保留监听。再次登录会创建新监听并重新遍历 `Transaction.unfinished`。此 UIKit 生命周期没有现成可注入的单元测试入口，以聚焦代码审查和模拟器构建验证，未新增仅供测试的生产 API。
- [x] 2026-09-22 验证：映射测试 6/6、购买测试 6/6、全量 Swift 测试 150/150；iPhone 17 Pro / iOS 26.1 模拟器构建退出码 0。真实 StoreKit 重放由适配器/登录链路代码审查和构建确认，沙盒交易仍待联调；构建有现存 Metal 工具链搜索路径警告。
- [x] 登出/重登修订后重新验证：全量 Swift 测试 150/150（包含删除失败保留会话的核心测试），模拟器构建退出码 0；构建仍有 Metal 路径及既有 `Components.swift` 可选值转 `Any` 警告。
- [x] 安全重试修订后验证：映射测试 11/11、购买测试 7/7、全量 Swift 测试 156/156，模拟器构建退出码 0（Metal 路径警告）。回归覆盖跨映射实例复用、非拥有者取消/错误清理、验证成功后新单、拥有者清理、旧尝试不删除新单，以及协调器发送原订单号验单。

### Task 4: JS Bridge 接入

- [x] 使用独立 `IAPBridgeHandler` 接入商品价格查询、购买、IAP 日志和并发购买保护。
- [x] 通过现有安全编码器回调 `getProductPriceResult` 与 `iapLog`，不向 JS 暴露收据或原始错误。
