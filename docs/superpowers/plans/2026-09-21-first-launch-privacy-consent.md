# First-launch Privacy Consent Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Gate all remote authentication behind explicit first-launch privacy consent.

**Architecture:** A small `PrivacyConsentStore` owns persistence. `CoastEnvironment` routes to a dedicated UIKit consent controller before constructing the remote login screen; policy links read the current runtime configuration snapshot.

**Tech Stack:** UIKit, SafariServices, UserDefaults, Swift Concurrency, XCTest, XCUITest.

## Global Constraints

- No authentication or configuration request may start before consent.
- Consent is independent of onboarding, logout, and account-ledger state.
- Reinstallation requires consent again.
- Policy and terms URLs must come from `IntegrationRuntimeConfiguration`.

---

### Task 1: Consent persistence

**Files:**
- Create: `CoastWild/Core/PrivacyConsentStore.swift`
- Create: `Tests/PrivacyConsentStoreTests.swift`

**Interfaces:**
- Produces: `PrivacyConsentStore.hasAcceptedConsent`, `accept()`, and `reset()`.

- [ ] Write tests proving a new store is unaccepted, acceptance persists, and reset removes acceptance.
- [ ] Run `swift test --filter PrivacyConsentStoreTests` and verify RED.
- [ ] Implement the minimal UserDefaults-backed store.
- [ ] Run the focused tests and verify GREEN.

### Task 2: First-launch routing and UI

**Files:**
- Create: `CoastWild/UI/PrivacyConsentController.swift`
- Modify: `CoastWild/App/AppDelegate.swift`
- Modify: `CoastWild.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `PrivacyConsentStore.hasAcceptedConsent` and `accept()`.
- Produces: accessibility identifiers `privacy.consent.agree`, `privacy.consent.decline`, `privacy.consent.policy`, and `privacy.consent.terms`.

- [ ] Add a fresh-install UI test that expects consent and no login button.
- [ ] Run the test and verify RED.
- [ ] Route unaccepted installations to the consent screen and accepted installations to remote login.
- [ ] Implement policy links, explicit agreement, and a non-networking declined state.
- [ ] Run the focused UI test and verify GREEN.

### Task 3: Relaunch and regression verification

**Files:**
- Modify: `UITests/CoastWildUITests.swift`
- Modify: `docs/integration-plans/05-账号注销与隐私合规计划.md`

**Interfaces:**
- Consumes: consent screen identifiers and existing `auth.remote.submit`.

- [ ] Update existing UI flows to accept consent after reset.
- [ ] Add relaunch and decline assertions.
- [ ] Run all Swift tests, simulator build, focused UI tests, and `git diff --check`.
- [ ] Mark the privacy plan status and commit the implementation.

