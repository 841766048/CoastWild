# First-launch Privacy Consent Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore the existing privacy-consent UI and gate all remote authentication behind it.

**Architecture:** A versioned `PrivacyConsentStore` owns persistence. `CoastEnvironment` routes to the restored UIKit consent flow before constructing remote login; the restored legal viewer consumes runtime privacy and terms URLs with bundled HTML fallback.

**Tech Stack:** UIKit, WebKit, SafariServices, UserDefaults, Swift Concurrency, XCTest, XCUITest.

## Global Constraints

- Preserve the previously implemented privacy-page layout and interactions.
- No authentication or configuration request may start before consent.
- Consent is independent of onboarding, logout, and account-ledger state.
- Reinstallation or a policy-version increase requires consent again.
- Policy and terms URLs come from `IntegrationRuntimeConfiguration`.

---

### Task 1: Versioned consent persistence

**Files:**
- Create: `CoastWild/Core/PrivacyConsentStore.swift`
- Create: `Tests/PrivacyConsentStoreTests.swift`

- [x] Write RED tests for new install, persistence, reset, and policy-version changes.
- [x] Implement the versioned UserDefaults store and verify GREEN.

### Task 2: Restore the existing page and legal viewer

**Files:**
- Create: `CoastWild/UI/PrivacyConsentController.swift`
- Create: `CoastWild/UI/LegalWebController.swift`
- Create: `CoastWild/Core/LegalDocument.swift`
- Create: `CoastWild/Resources/Legal/*`
- Create: `CoastWild/Resources/Assets.xcassets/privacy-hero.imageset/*`
- Modify: `CoastWild/App/AppDelegate.swift`

- [x] Restore the established hero, checkbox, linked agreement, validation, and decline-sheet UI.
- [x] Route unaccepted installs to that page and accepted installs to remote login.
- [x] Use runtime legal URLs with secure bundled HTML fallback.

### Task 3: Regression verification

**Files:**
- Modify: `UITests/CoastWildUITests.swift`
- Modify: `docs/integration-plans/05-账号注销与隐私合规计划.md`

- [x] Verify privacy gating, legal navigation, unchecked validation, decline, acceptance, and relaunch.
- [x] Run all Swift tests, simulator build, full XCUITest suite, and `git diff --check`.
- [x] Mark the privacy plan status and commit the implementation.
