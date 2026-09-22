# Remote Login UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the local preview account screens with a device-based remote login portal, remote-user ledger activation, and remote logout.

**Architecture:** A main-actor login presentation model translates coordinator states into deterministic UI state. `RemoteLoginController` owns automatic/manual login and connectivity presentation; `CoastEnvironment` owns root routing and dependency composition.

**Tech Stack:** UIKit, Network, Swift Concurrency, XCTest, XCUITest.

## Global Constraints

- No local account or test data migration.
- Login UI contains no email/password/register/recovery entry.
- UI tests never access the live service.
- Logout clears remote session but retains device UUID and ledger files.

---

### Task 1: Testable login presentation and UI fixture

**Files:**
- Create: `CoastWild/Core/RemoteLoginPresentation.swift`
- Create: `Tests/RemoteLoginPresentationTests.swift`
- Create: `CoastWild/App/UITestRemoteAuthenticationAPI.swift`

- [x] Write failing tests for idle, loading, authenticated, offline, and retryable failure presentation.
- [x] Run `swift test --filter RemoteLoginPresentationTests` and verify RED.
- [x] Implement pure state translation and deterministic UI-test API fixture.
- [x] Run focused tests and commit `feat: add remote login presentation`.

### Task 2: Remote login controller and routing

**Files:**
- Rewrite: `CoastWild/UI/AuthController.swift`
- Modify: `CoastWild/App/AppDelegate.swift`
- Create: `CoastWild/App/ConnectivityMonitor.swift`

- [x] Add presentation and UI assertions for remote-login identifiers and removal of local fields.
- [x] Replace the obsolete local-login UI assertions with the remote-login contract.
- [x] Implement one-button login, automatic login, loading/error states, offline alert, settings action, and remote-user ledger activation.
- [x] Route startup through the login portal and normal/UI-test dependencies through the same coordinator interface.
- [x] Run focused and full tests; commit `feat: replace local auth with remote login`.

### Task 3: Remote logout and UI regression

**Files:**
- Modify: `CoastWild/UI/ProfileController.swift`
- Modify: `UITests/CoastWildUITests.swift`
- Modify: `docs/integration-plans/04-远程登录与账号迁移计划.md`

- [x] Update account copy and logout to clear the remote session before returning to the portal.
- [x] Replace registration/recovery UI tests with remote login, persisted automatic login, and logout assertions.
- [x] Run bootstrap, all Swift tests, focused XCUITest, Simulator build, and `git diff --check`.
- [x] Mark plans complete and commit `feat: complete remote login UI`.
