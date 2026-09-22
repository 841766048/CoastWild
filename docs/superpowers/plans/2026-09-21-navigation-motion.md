# Navigation Motion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the approved restrained-native motion system for hierarchy navigation, tab switching, and custom dialogs.

**Architecture:** Keep timing values in a pure `CoastMotion` contract that Core tests can verify. Centralize UIKit behavior in `CoastNavigationController`, a transition animator, `CoastTabBarController`, and `CoastDialog`; business controllers continue to request navigation without owning animation details.

**Tech Stack:** Swift 5, UIKit, `UIViewPropertyAnimator`, XCTest/XCUITest, iOS 17+

## Global Constraints

- Push is 0.28 seconds and Pop is 0.24 seconds with immediate, non-elastic deceleration.
- Tab changes fade and move up by 6pt over 0.18 seconds.
- Dialog open is 0.22 seconds from scale 0.96; close is 0.16 seconds to scale 0.98.
- Preserve the system interactive edge-swipe back gesture.
- Reduce Motion disables navigation and Tab spatial travel; dialog motion becomes a fade no longer than 0.12 seconds.
- Do not change layout, typography, colors, business data, or navigation destinations.

---

### Task 1: Motion contract

**Files:**
- Modify: `CoastWild/Core/Models.swift`
- Modify: `Tests/CoastWildCoreTests.swift`

**Interfaces:**
- Produces: `CoastMotion.pushDuration`, `popDuration`, `tabDuration`, `tabOffset`, `dialogOpenDuration`, `dialogCloseDuration`, `dialogOpenScale`, `dialogCloseScale`, and `reducedDuration` as `Double` constants.

- [x] Add `testMotionContractMatchesApprovedTiming` asserting `0.28`, `0.24`, `0.18`, `6`, `0.22`, `0.16`, `0.96`, `0.98`, and a reduced duration no greater than `0.12`.
- [x] Run `swift test --filter CoastWildCoreTests.testMotionContractMatchesApprovedTiming` and verify it fails because `CoastMotion` does not exist.
- [x] Add the minimal public constants to `Models.swift`.
- [x] Run `swift test --filter CoastWildCoreTests.testMotionContractMatchesApprovedTiming` and verify it passes.

### Task 2: Hierarchy and Tab transitions

**Files:**
- Modify: `CoastWild/App/AppDelegate.swift`
- Modify: `UITests/CoastWildUITests.swift`

**Interfaces:**
- Consumes: `CoastMotion` constants.
- Produces: `CoastNavigationAnimator`, enhanced `CoastNavigationController`, and `CoastTabBarController`.

- [x] Extend the existing end-to-end UI test to switch Tabs rapidly, push a detail page, return, and assert the destination remains correct.
- [x] Run the focused UI test against the baseline and record that navigation works before custom motion, while the motion-contract test remains the behavioral red gate.
- [x] Replace root `UITabBarController()` with `CoastTabBarController()`.
- [x] Implement Push/Pop with `UIViewPropertyAnimator` using full-width incoming travel, restrained outgoing parallax, and cleanup that honors cancellation.
- [x] Keep the interactive pop gesture enabled whenever the navigation stack has more than one controller.
- [x] Override direct push/pop/pop-to-root/set-controller calls so Reduce Motion suppresses spatial animation globally.
- [x] Implement Tab fade/y-offset transition with `.beginFromCurrentState` and no animation for first display or Reduce Motion.
- [x] Run the focused UI test and verify rapid Tab switching, Push, Pop, and existing destinations pass.

### Task 3: Dialog transition and regression

**Files:**
- Modify: `CoastWild/UI/Components.swift`
- Modify: `UITests/CoastWildUITests.swift`
- Create: `docs/navigation-motion-verification.md`

**Interfaces:**
- Consumes: `CoastMotion` constants and `UIAccessibility.isReduceMotionEnabled`.
- Produces: synchronized overlay/card open and close animations inside `CoastDialog`.

- [x] Extend the UI flow to open and close an existing custom confirmation dialog and confirm its action still executes once.
- [x] Store the dialog card as a property, initialize its visible state before presentation, and animate overlay opacity plus card scale/opacity in `viewDidAppear`.
- [x] Route every dialog action through one close method, animate to scale 0.98, then dismiss without a second system transition and invoke the action once.
- [x] Use fade-only timing no longer than 0.12 seconds under Reduce Motion.
- [x] Run `swift test`, the full UI test suite, workspace build, and `git diff --check`; record logs and remaining simulator limitations.
