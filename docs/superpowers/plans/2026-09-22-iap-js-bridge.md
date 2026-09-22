# IAP JS Bridge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the existing StoreKit 2 catalog and purchase coordinator callable through the validated business WebView Bridge.

**Architecture:** Add an actor adapter that consumes typed `BridgeMessage` values and returns presentation-neutral commands. `BusinessWebController` applies those commands with the existing safe JavaScript callback encoder, while `CoastEnvironment` owns a handler built from the same StoreKit store and purchase coordinator.

**Tech Stack:** Swift Concurrency, StoreKit 2, WKWebView, XCTest.

## Global Constraints

- Do not add a third-party IAP dependency.
- Do not bypass `BridgeRouter` host or main-frame validation.
- Do not expose receipts, signed transactions, tokens, or raw server errors to JavaScript.
- Preserve the documented `iapLog` and `getProductPriceResult` callback names.
- Restore purchases remains a native account-screen action.

---

### Task 1: Typed IAP Bridge adapter

**Files:**
- Create: `CoastWild/Core/IAPBridgeHandler.swift`
- Create: `Tests/IAPBridgeHandlerTests.swift`

**Interfaces:**
- Consumes: `BridgeMessage`, `ProductCatalog`, `PurchaseCoordinator`, `PurchaseLogPayload`.
- Produces: `IAPBridgeCommand`, `IAPBridgeHandling.handle(_:) async throws`.

- [x] **Step 1: Write failing adapter tests**

Cover `GetProductPrice`, purchased, pending, cancelled, runtime failure, `LogPurchase`, unsupported messages, and two simultaneous purchase messages. Assert that every JavaScript-facing failure uses a stable code and contains no receipt or raw error text.

- [x] **Step 2: Verify the tests fail because the adapter types do not exist**

Run: `swift test --filter IAPBridgeHandlerTests`

Expected: compilation failure for missing `IAPBridgeHandler` and `IAPBridgeCommand`.

- [x] **Step 3: Implement the minimal actor adapter**

Define commands for product prices and IAP log values. Map purchase terminal states to structured, receipt-free log objects. Inject a sendable purchase-event closure for `LogPurchase`. Reject unsupported messages and concurrent purchases.

- [x] **Step 4: Verify adapter tests pass**

Run: `swift test --filter IAPBridgeHandlerTests`

Expected: all adapter tests pass.

---

### Task 2: WebView and application wiring

**Files:**
- Modify: `CoastWild/UI/BusinessWebController.swift`
- Modify: `CoastWild/App/AppDelegate.swift`
- Modify: `Tests/IAPBridgeHandlerTests.swift`
- Modify: `docs/integration-plans/08-IAP内购与权益计划.md`

**Interfaces:**
- Consumes: `IAPBridgeHandling`, `IAPBridgeCommand`, `JavaScriptCallbackEncoder`.
- Produces: automatic dispatch of the four IAP Bridge topics from `BusinessWebController`.

- [x] **Step 1: Write failing command-to-callback tests**

Assert that price commands encode with `getProductPriceResult` and purchase/log commands encode with `iapLog`, including quotes, backslashes, newlines, and Unicode.

- [x] **Step 2: Verify the new tests fail before wiring**

Run: `swift test --filter IAPBridgeHandlerTests`

Expected: failure for missing command callback encoding.

- [x] **Step 3: Wire the handler**

Add a safe callback encoder to `IAPBridgeCommand`, let `BusinessWebController` send IAP messages to the handler asynchronously, and initialize one handler in `CoastEnvironment` from the same `StoreKit2PurchaseStore` used by `PurchaseCoordinator`. Non-IAP messages continue through the existing closure.

- [x] **Step 4: Regenerate and verify**

Run:

```bash
./scripts/bootstrap.sh
swift test
xcodebuild -workspace CoastWild.xcworkspace -scheme CoastWild -sdk iphonesimulator -destination 'platform=iOS Simulator,id=5D9E1931-9B36-479E-8448-2CA6F0F1D802' build
```

Expected: 0 test failures and `BUILD SUCCEEDED`.

- [x] **Step 5: Commit**

```bash
git add CoastWild Tests docs CoastWild.xcodeproj/project.pbxproj docs/superpowers/plans/2026-09-22-iap-js-bridge.md
git commit -m "feat: connect IAP to JavaScript bridge"
```
