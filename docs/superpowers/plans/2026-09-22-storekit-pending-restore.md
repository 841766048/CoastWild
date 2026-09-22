# StoreKit Pending and Restore Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Verify later-approved pending purchases and restore verified StoreKit entitlements without requiring a surviving local order mapping.

**Architecture:** A Foundation-only `PurchaseOrderMappingStore` owns pending-product and transaction-order persistence in `UserDefaults`, making mapping migration independently testable. `StoreKit2PurchaseStore` delegates mapping operations to it, emits verified transaction updates after migrating pending orders, and includes verified current entitlements even when their optional order ID is absent.

**Tech Stack:** Swift 5.9, Foundation, StoreKit 2, XCTest, iOS 17+

## Global Constraints

- `Transaction.currentEntitlements` is the restoration source of truth.
- Only verified StoreKit transactions may reach server verification.
- Missing restore order IDs are represented as `nil`; signed StoreKit transaction data remains mandatory.
- Finish only after successful server verification and preserve retry behavior after failures.
- Do not change JavaScript Bridge payloads, public purchase APIs, server endpoints, App Store Connect configuration, or receipt/JWS logging.
- Preserve all unrelated dirty-worktree changes.

---

### Task 1: Testable order mapping lifecycle

**Files:**
- Create: `CoastWild/Core/PurchaseOrderMappingStore.swift`
- Create: `Tests/PurchaseOrderMappingStoreTests.swift`

**Interfaces:**
- Produces: `PurchaseOrderMappingStore.init(defaults:keyPrefix:)`, `stage(orderID:forProductID:)`, `cancelPending(productID:)`, `associate(orderID:transactionID:)`, `resolveForUpdate(transactionID:productID:)`, `orderID(forTransactionID:)`, `restoredTransaction(productID:transactionID:signedData:)`, and `finish(transactionID:)`.
- Consumes: `UserDefaults` and the existing key prefix `com.coastwild.iap.order.`.

- [ ] **Step 1: Write failing mapping tests**

Create tests covering these exact behaviors:

```swift
func testPendingOrderMigratesToTransactionAndIsConsumed() {
  mapping.stage(orderID: "order-pending", forProductID: "monthly")
  XCTAssertEqual(mapping.resolveForUpdate(transactionID: "tx-1", productID: "monthly"), "order-pending")
  XCTAssertEqual(mapping.orderID(forTransactionID: "tx-1"), "order-pending")
  XCTAssertNil(mapping.resolveForUpdate(transactionID: "tx-2", productID: "monthly"))
}

func testExistingTransactionMappingWinsWithoutConsumingPendingOrder() {
  mapping.stage(orderID: "new-order", forProductID: "monthly")
  mapping.associate(orderID: "old-order", transactionID: "tx-old")
  XCTAssertEqual(mapping.resolveForUpdate(transactionID: "tx-old", productID: "monthly"), "old-order")
  XCTAssertEqual(mapping.resolveForUpdate(transactionID: "tx-new", productID: "monthly"), "new-order")
}

func testRestoreLookupAndFinishAllowMissingMapping() {
  XCTAssertNil(mapping.orderID(forTransactionID: "unknown"))
  XCTAssertEqual(
    mapping.restoredTransaction(productID: "monthly", transactionID: "unknown", signedData: "signed"),
    StoreTransaction(productID: "monthly", transactionID: "unknown", signedData: "signed", orderID: nil)
  )
  mapping.associate(orderID: "order-1", transactionID: "tx-1")
  mapping.finish(transactionID: "tx-1")
  XCTAssertNil(mapping.orderID(forTransactionID: "tx-1"))
}
```

Use a unique `UserDefaults` suite per test and delete its persistent domain in teardown.

- [ ] **Step 2: Verify RED**

Run:

```bash
swift test --filter PurchaseOrderMappingStoreTests
```

Expected: compilation fails because `PurchaseOrderMappingStore` does not exist.

- [ ] **Step 3: Implement the mapping store**

Implement a small value type that uses keys `<prefix>pending.<productID>` and `<prefix><transactionID>`. `resolveForUpdate` must first return an existing transaction mapping; otherwise it reads the pending mapping, writes the transaction mapping, removes the pending mapping, and returns the migrated order ID. `restoredTransaction` must always return a `StoreTransaction`, using the optional transaction mapping when present.

- [ ] **Step 4: Verify GREEN**

Run the filtered test and expect three tests with zero failures.

- [ ] **Step 5: Commit Task 1**

```bash
git add CoastWild/Core/PurchaseOrderMappingStore.swift Tests/PurchaseOrderMappingStoreTests.swift docs/superpowers/plans/2026-09-22-storekit-pending-restore.md
git commit -m "fix: persist pending purchase associations"
```

### Task 2: Wire verified StoreKit updates and restore

**Files:**
- Modify: `CoastWild/App/StoreKit2PurchaseStore.swift`
- Modify: `Tests/PurchaseTests.swift`
- Modify: `docs/integration-plans/08-IAP内购与权益计划.md`

**Interfaces:**
- Consumes: `PurchaseOrderMappingStore` from Task 1 and existing `StoreTransaction.orderID: String?`.
- Produces: verified delayed transaction updates with migrated order IDs, and verified restored entitlements with optional order IDs.

- [ ] **Step 1: Add a failing coordinator restore test**

Extend the purchase server fake to record received order IDs. Add a test that restores a verified fake transaction whose `orderID` is `nil`, asserts the server receives `nil`, asserts the entitlement becomes active, and asserts the transaction is finished. This proves the coordinator contract accepts mapping-free restoration.

Extract an injectable, testable purchase-operation seam if doing so stays small and localized. Use it to add a regression test that a thrown `product.purchase()` clears the staged pending mapping before rethrowing, while a normal `.pending` result retains that mapping. The existing cancellation path must also clear the staged mapping. If a seam would add disproportionate StoreKit-facing indirection, document focused code-review and simulator-build evidence instead of adding a brittle source-reading test; that review must confirm `product.purchase()` is wrapped in `do`/`catch`, the catch calls `cancelPending(productID:)` before rethrowing, normal `.pending` does not clear the mapping, and cancellation does.

- [ ] **Step 2: Verify RED for mapping-free restoration**

Before adding `restoredTransaction` to the mapping store, run its focused test and confirm it fails because the method is missing. After Task 1 supplies the method, run the new coordinator test to prove that the downstream server contract accepts and finishes a restored transaction whose order ID is `nil`.

- [ ] **Step 3: Wire `PurchaseOrderMappingStore`**

In `StoreKit2PurchaseStore`:

- Replace direct pending and transaction `UserDefaults` access with the mapping store.
- On immediate verified success, associate the transaction ID and cancel the pending product mapping.
- Wrap `product.purchase()` in `do`/`catch`; on a thrown purchase call `cancelPending(productID:)` before rethrowing. Keep the staged mapping for a normal `.pending` result, and clear it for cancellation.
- In `transactionUpdates`, use `resolveForUpdate(transactionID:productID:)`; yield only when it returns an order ID because a delayed purchase must retain its server-order association.
- In `restore`, append `restoredTransaction(productID:transactionID:signedData:)` for every verified current entitlement without an order-mapping guard.
- In `finish`, remove only the temporary transaction mapping after finishing StoreKit.

- [ ] **Step 4: Update plan evidence and verify**

Mark the pending, thrown-purchase cleanup, cancellation cleanup, and restore regression coverage in plan 08. Run:

```bash
swift test --filter PurchaseOrderMappingStoreTests
swift test --filter PurchaseTests
swift test
xcodebuild build -workspace CoastWild.xcworkspace -scheme CoastWild -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.1'
```

Expected: all filtered tests and all Swift tests pass; simulator build succeeds.

- [ ] **Step 5: Commit Task 2**

```bash
git add CoastWild/App/StoreKit2PurchaseStore.swift Tests/PurchaseTests.swift docs/integration-plans/08-IAP内购与权益计划.md
git commit -m "fix: restore StoreKit transactions without local orders"
```
