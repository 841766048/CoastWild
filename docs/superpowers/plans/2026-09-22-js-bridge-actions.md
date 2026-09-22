# JS Bridge Business Actions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every supported business-Web JS topic perform its documented native action or an explicit safe no-op.

**Architecture:** Add a Foundation-only action planner that converts validated `BridgeMessage` values into stable application actions. `BusinessWebController` executes WebKit/UIKit-local actions while `CoastEnvironment` executes authentication, state, and refresh actions through injected callbacks.

**Tech Stack:** Swift 5.9, UIKit, WebKit, SafariServices, StoreKit, XCTest, Swift Package Manager, Xcode workspace.

## Global Constraints

- Preserve `BridgeRouter` trusted HTTPS host and main-frame checks.
- Keep `onCreateOrder` registered but unsupported.
- Never log authentication, device, order, receipt, JWS, or full URL-query values.
- Preserve unrelated dirty working-tree changes and stage only task-owned hunks.
- Use TDD for every new Foundation behavior.

---

### Task 1: Foundation action planning

**Files:**
- Create: `CoastWild/Core/BusinessBridgeAction.swift`
- Create: `Tests/BusinessBridgeActionTests.swift`
- Modify: `CoastWild.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `BridgeMessage` from `BridgeMessage.swift`.
- Produces: `BusinessBridgeAction`, `BusinessBridgeActionPlanner.action(for:)`, `BridgeLanguage.normalized(_:)`, and `BridgeNativeLog.sanitizedSummary(_:)`.

- [ ] **Step 1: Write failing mapping tests**

Cover all non-IAP actions: background login, reveal, Safari, external link, internal web, settings, review, edge pan, logout, language, entitlement refresh, native log, and the three JS callbacks.

- [ ] **Step 2: Run tests and verify RED**

Run: `swift test --filter BusinessBridgeActionTests`
Expected: compilation failure because the action types do not exist.

- [ ] **Step 3: Implement minimal action planner**

Use an exhaustive switch over `BridgeMessage`; return `nil` only for IAP messages already owned by `IAPBridgeHandler` and `onCreateOrder`.

- [ ] **Step 4: Add language and log sanitization tests, then implementation**

Language maps values beginning with `zh` to `zh-Hans` and all other supported values to `en`. Native logs strip control characters, redact bearer/JWS-like tokens and URL query values, and cap summaries at 160 characters.

- [ ] **Step 5: Run focused tests and commit**

Run: `swift test --filter BusinessBridgeActionTests`
Expected: all focused tests pass.

Commit: `feat: plan JS bridge business actions`

### Task 2: WebView-local native actions

**Files:**
- Modify: `CoastWild/UI/BusinessWebController.swift`
- Modify: `CoastWild/Core/BusinessWebNavigationPolicy.swift`
- Test: `Tests/BusinessWebTests.swift`

**Interfaces:**
- Consumes: `BusinessBridgeActionPlanner` and application-level action callback.
- Produces: application Safari presentation, external opening, settings, review request, reveal state, edge-pan control, and safe JavaScript callbacks.

- [ ] **Step 1: Write failing policy/action tests**

Add tests proving Safari and external-link actions retain HTTPS validation, reveal is idempotent, and edge-pan state preserves requested edge.

- [ ] **Step 2: Run tests and verify RED**

Run: `swift test --filter BusinessWebTests`
Expected: new state/policy API is missing.

- [ ] **Step 3: Implement controller behavior**

Import SafariServices and StoreKit. Add one edge recognizer, a launch cover, action execution, and injectable closures for application-level actions. Use `SFSafariViewController`, `UIApplication.openSettingsURLString`, `SKStoreReviewController`, and `WKWebView.goBack()`.

- [ ] **Step 4: Preserve internal-Web and IAP ownership**

Keep `OpenInternalWeb`, `newTppClose`, and IAP handling on their existing paths. Route all remaining messages through the action planner.

- [ ] **Step 5: Run focused tests and compile**

Run: `swift test --filter 'BusinessWebTests|BridgeTests|BusinessBridgeActionTests'`
Expected: all focused tests pass.

Run: `xcodebuild -workspace CoastWild.xcworkspace -scheme CoastWild -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build`
Expected: `BUILD SUCCEEDED`.

Commit: `feat: execute native web bridge actions`

### Task 3: Application-level actions and background-login callback

**Files:**
- Modify: `CoastWild/App/AppDelegate.swift`
- Modify: `CoastWild/UI/BusinessWebController.swift`
- Modify: `Tests/RemoteSessionCoordinatorTests.swift`
- Modify: `docs/integration-plans/07-JS-Bridge对接计划.md`

**Interfaces:**
- Consumes: application-level `BusinessBridgeAction` values.
- Produces: background-login result callback, logout, entitlement refresh, language persistence, and sanitized native logging.

- [ ] **Step 1: Add failing background-login tests**

Verify the existing coordinator performs config → OAuth → strategy, preserves the current session on failure, and rejects concurrent starts.

- [ ] **Step 2: Run tests and verify RED where behavior is absent**

Run: `swift test --filter RemoteSessionCoordinatorTests`
Expected: the new application dispatch contract test fails before wiring.

- [ ] **Step 3: Wire application actions**

Pass a weak-controller callback from `remoteAuthenticated`. Background login calls the coordinator and sends `backgroundLoginSuccess` with the refreshed bootstrap payload; logout reuses the existing lifecycle-safe method; language persists normalized preferences; entitlement refresh invokes restore; native log records only sanitized metadata.

- [ ] **Step 4: Update integration plan and run regression tests**

Mark the implemented topics and retain external verification gates.

Run: `swift test`
Expected: all tests pass with zero failures.

- [ ] **Step 5: Run final simulator build and commit**

Run: `xcodebuild -workspace CoastWild.xcworkspace -scheme CoastWild -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build`
Expected: `BUILD SUCCEEDED`.

Commit: `feat: complete JS bridge business handling`

### Task 4: Independent review and delivery verification

**Files:**
- Review all files changed since `1e2c096`.

- [ ] **Step 1: Review every topic against the design**

Confirm each topic has one owner and no topic is silently dropped.

- [ ] **Step 2: Review security boundaries**

Confirm untrusted sources/subframes remain rejected and logs/callbacks cannot leak secrets or inject JavaScript.

- [ ] **Step 3: Run fresh verification**

Run full `swift test` and workspace simulator build after all review corrections.

- [ ] **Step 4: Report external validation limits**

Record that live H5 topic emission, App Store review UI, settings launch, Safari presentation, and real background-login service behavior require simulator/device integration checks.
