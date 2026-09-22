# Business Web Navigation Bar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep the primary business WebView's top navigation bar hidden every time that controller appears.

**Architecture:** `BusinessWebController` owns its presentation chrome and enforces its hidden navigation state in `viewWillAppear(_:)`. A UI-test-only `AppDelegate` fixture embeds that controller in a plain navigation controller whose bar starts visible, isolating the lifecycle contract. `InternalWebController` retains its per-page behavior.

**Tech Stack:** Swift 5, UIKit, WebKit, XCTest/XCUITest, iOS 17+

## Global Constraints

- Hide only `UINavigationBar`; do not change the status bar or Home Indicator.
- Do not change Web URL resolution, JavaScript bridge behavior, safe-area injection, or internal WebView rules.
- Preserve all unrelated changes in the dirty worktree.

---

### Task 1: Enforce hidden navigation chrome on appearance

**Files:**
- Modify: `UITests/CoastWildUITests.swift`
- Modify: `CoastWild/App/AppDelegate.swift`
- Modify: `CoastWild/UI/BusinessWebController.swift`

**Interfaces:**
- Consumes: `UIViewController.viewWillAppear(_:)` and `UINavigationController.setNavigationBarHidden(_:animated:)`.
- Produces: `BusinessWebController.viewWillAppear(_:)`, which guarantees `navigationController?.isNavigationBarHidden == true` while the primary WebView is visible.

- [ ] **Step 1: Write the failing regression test**

Add this UI test:

```swift
func testBusinessWebHidesNavigationBarWhenItAppears() {
  let app = XCUIApplication()
  app.launchArguments = ["--ui-testing", "--reset-test-data",
                         "--ui-testing-business-web-navigation"]
  app.launch()
  XCTAssertTrue(app.webViews["business-web.main"].waitForExistence(timeout: 10))
  XCTAssertFalse(app.navigationBars.firstMatch.exists)
}
```

In `AppDelegate`, add a UI-test-only fixture that constructs `BusinessWebController` in a plain `UINavigationController`, deliberately exposes that bar, and then assigns it as the root controller:

```swift
let nav = UINavigationController(rootViewController: controller)
nav.setNavigationBarHidden(false, animated: false)
window?.rootViewController = nav
```

This isolates the controller lifecycle: without `BusinessWebController.viewWillAppear(_:)`, the navigation bar remains visible. Do not change `CoastNavigationController` for this test.

- [ ] **Step 2: Run the focused UI test and verify RED**

Run:

```bash
xcodebuild test -workspace CoastWild.xcworkspace -scheme CoastWild -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.1' -only-testing:CoastWildUITests/CoastWildUITests/testBusinessWebHidesNavigationBar
```

Expected: FAIL because `BusinessWebController` does not currently re-hide the bar from its appearance lifecycle.

- [ ] **Step 3: Implement the minimal lifecycle behavior**

Add to `BusinessWebController`:

```swift
override func viewWillAppear(_ animated: Bool) {
  super.viewWillAppear(animated)
  navigationController?.setNavigationBarHidden(true, animated: animated)
}
```

Keep `InternalWebController` unchanged so its existing `showsNavigationBar` contract continues to work.

- [ ] **Step 4: Run focused and full verification**

Run the focused UI test again and expect PASS. Then run:

```bash
swift test
xcodebuild build -workspace CoastWild.xcworkspace -scheme CoastWild -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.1'
```

Expected: all Swift tests pass and the simulator build succeeds.

- [ ] **Step 5: Commit only this behavior change**

```bash
git add CoastWild/App/AppDelegate.swift CoastWild/UI/BusinessWebController.swift UITests/CoastWildUITests.swift docs/superpowers/plans/2026-09-22-business-web-navigation-bar.md
git commit -m "fix: hide navigation bar for business web"
```

### Task 2: Preserve the business-Web contract in CoastNavigationController

- Keep the plain-`UINavigationController` regression as the direct proof of `BusinessWebController.viewWillAppear(_:)`.
- Add a second UI-test-only fixture using `CoastNavigationController` with its bar initially visible, and assert the primary business WebView hides it.
- Add `BusinessWebController` to the hidden-controller condition in `CoastNavigationController`; do not change `InternalWebController` behavior.
- Run each fully qualified UI-test selector independently, then `swift test` and the simulator build.
