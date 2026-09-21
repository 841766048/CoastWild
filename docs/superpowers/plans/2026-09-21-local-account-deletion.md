# Local Simulated Account Deletion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a clearly labeled simulated account-deletion request that deletes only the current account's local data after success, preserves everything after failure, and exposes distinct logout, clear-space, and delete-account UI actions.

**Architecture:** A core `AccountDeletionService` sequences an injected async remote action, local account cleanup, and session cleanup. `CoastStore` owns removal of the current ledger file; the UIKit environment supplies photo and navigation cleanup. Legal files describe the current behavior and future integrations accurately.

**Tech Stack:** Swift 5, Foundation, UIKit, XCTest, XCUITest.

## Global Constraints

- Do not invent an HTTP endpoint or claim server-side deletion.
- A failed simulated request must leave session and local account data untouched.
- Device identity survives account deletion.
- The confirmation must mention irreversibility and separate Apple subscription cancellation.

---

### Task 1: Deletion transaction and account storage removal

**Files:**
- Create: `CoastWild/Core/AccountDeletionService.swift`
- Create: `Tests/AccountDeletionTests.swift`
- Modify: `CoastWild/Core/CoastStore.swift`
- Modify: `Tests/CoastWildCoreTests.swift`

**Interfaces:**
- Produces: `AccountDeletionService.deleteAccount() async throws`, `AccountDeletionService.isDeleting`, and `CoastStore.deleteCurrentAccountData()`.
- Consumes: injected `remoteDelete`, `localDelete`, and `sessionDelete` closures.

- [x] Write tests proving remote failure performs no cleanup, success calls `remote/local/session` in order, local failure does not clear the session, duplicate execution is rejected, and deleting one account preserves another.
- [x] Run `swift test --filter AccountDeletionTests` and the focused store test; confirm failure because the APIs do not exist.
- [x] Implement the minimal transaction and current-ledger file deletion.
- [x] Re-run focused and full Swift tests.

### Task 2: App integration and three distinct actions

**Files:**
- Modify: `CoastWild/App/AppDelegate.swift`
- Modify: `CoastWild/UI/ProfileController.swift`
- Modify: `UITests/CoastWildUITests.swift`

**Interfaces:**
- Consumes: `AccountDeletionService.deleteAccount()` and `CoastStore.deleteCurrentAccountData()`.
- Produces: accessibility identifiers `account.logout`, `account.delete`, `privacy.clear-space`, and deletion confirmation controls.

- [x] Add UI assertions for the three independent actions, confirmation copy, simulated failure recovery, and successful return to login.
- [x] Run the focused UI test and confirm it fails on missing identifiers/actions.
- [x] Inject a delayed simulated remote action, add the account-deletion environment method, and implement progress, confirmation, success, and retry UI.
- [x] Re-run the focused UI test.

### Task 3: Legal copy and entry points

**Files:**
- Modify: `CoastWild/Resources/Legal/privacy-en.html`
- Modify: `CoastWild/Resources/Legal/privacy-zh-Hans.html`
- Modify: `CoastWild/Resources/Legal/terms-en.html`
- Modify: `CoastWild/Resources/Legal/terms-zh-Hans.html`
- Modify: `CoastWild/UI/ProfileController.swift`
- Create: `Tests/LegalDocumentTests.swift`

**Interfaces:**
- Produces: bundled bilingual disclosure covering remote accounts, device ID, H5, payments, attribution, retention, deletion, and contact.

- [x] Write a resource-contract test for required bilingual disclosure topics and confirm it fails against current files.
- [x] Update legal copy and add privacy/terms rows to settings while preserving the existing first-launch and login entry points.
- [x] Re-run legal tests, all Swift tests, focused UI tests, and a simulator build.
- [x] Mark plan 05 and the combined 04–05 gate complete, then commit the verified changes.
