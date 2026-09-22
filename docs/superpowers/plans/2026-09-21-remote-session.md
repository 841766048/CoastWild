# Remote Session Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the pre-release local authentication foundation with stable device identity, validated remote-session persistence, and automatic/manual/background login orchestration.

**Architecture:** Focused actors own device identity, session persistence, and login state. `RemoteSessionCoordinator` depends on a protocol implemented by `IntegrationAPIClient`, so tests use deterministic fakes and never call the live service.

**Tech Stack:** Swift 5.9, Foundation, Security, Swift Concurrency, XCTest.

## Global Constraints

- Existing local accounts and data are test-only and are not migrated, imported, or rebound.
- Device UUID resolution order is UserDefaults, Keychain, then generated UUID.
- Keychain accessibility is `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
- OAuth `isFirstRegister` is numeric and true only when equal to `1`.
- Logout clears the remote session but retains the device UUID and business data.
- Tests use fakes and do not access the live service.

---

### Task 1: Device identity storage

**Files:**
- Create: `CoastWild/Core/DeviceIdentityStore.swift`
- Create: `Tests/DeviceIdentityStoreTests.swift`

**Interfaces:**
- Consumes: bundle identifier, `UserDefaults`, Keychain read/write abstraction, UUID generator.
- Produces: `DeviceIdentityStore.resolve() async throws -> String`, `KeychainValueStoring`, and `SecurityKeychainValueStore`.

- [x] **Step 1: Write failing storage-order tests**

Add tests proving a nonempty `uuidKey` default wins without Keychain access, a Keychain value is restored into defaults, and a generated lowercase UUID is written to both stores. The fake Keychain records the requested account and accessibility value.

- [x] **Step 2: Verify RED**

Run: `swift test --filter DeviceIdentityStoreTests`

Expected: compilation fails because `DeviceIdentityStore` and `KeychainValueStoring` do not exist.

- [x] **Step 3: Implement minimal identity storage**

Create an actor whose initializer accepts `bundleIdentifier`, `UserDefaults`, `any KeychainValueStoring`, and `uuidGenerator: @Sendable () -> UUID`. Implement the exact three-level lookup and store the Keychain item under `"\(bundleIdentifier)_UUID"` with after-first-unlock-this-device-only accessibility.

- [x] **Step 4: Verify GREEN and commit**

Run: `swift test --filter DeviceIdentityStoreTests && git diff --check`

Expected: all device identity tests pass and diff check is empty.

Commit: `feat: add persistent device identity`

### Task 2: Remote session model and store

**Files:**
- Create: `CoastWild/Core/RemoteSession.swift`
- Create: `CoastWild/Core/RemoteSessionStore.swift`
- Create: `Tests/RemoteSessionStoreTests.swift`

**Interfaces:**
- Consumes: OAuth `JSONValue` response and injected `UserDefaults`.
- Produces: `RemoteSession.init(oauthResponse:)`, `requestSession`, `RemoteSessionStore.session()`, `save(_:)`, `clear()`, `hasLoggedInBefore()`, and `markLoginSucceeded()`.

- [x] **Step 1: Write failing decoding and persistence tests**

Cover complete OAuth decoding, numeric values `0`, `1`, and `2`, missing/blank token or `userInfo.userId`, round-trip persistence under `LanlinLoginData`, malformed data rejection, `logindKey`, and clear behavior.

- [x] **Step 2: Verify RED**

Run: `swift test --filter RemoteSessionStoreTests`

Expected: compilation fails because the remote-session types do not exist.

- [x] **Step 3: Implement the session model and actor**

Persist a Codable `RemoteSession` containing `token`, `userID`, numeric `isFirstRegister`, and encoded original response data. Reject incomplete responses with `RemoteSessionError.invalidOAuthResponse`. Expose `RequestSession(token:userID:)` from the validated model. Treat malformed persisted data as absent and remove it.

- [x] **Step 4: Verify GREEN and commit**

Run: `swift test --filter RemoteSessionStoreTests && swift test`

Expected: focused and full test suites pass.

Commit: `feat: persist validated remote sessions`

### Task 3: Login coordinator

**Files:**
- Create: `CoastWild/Core/RemoteSessionCoordinator.swift`
- Create: `Tests/RemoteSessionCoordinatorTests.swift`
- Modify: `CoastWild/Core/IntegrationAPIClient.swift`

**Interfaces:**
- Consumes: `RemoteAuthenticationAPI`, `DeviceIdentityStore`, and `RemoteSessionStore`.
- Produces: `RemoteSessionCoordinator.automaticLogin()`, `manualLogin(riskInfo:)`, `backgroundLogin(riskInfo:)`, `logout()`, and `state()`.

- [x] **Step 1: Write failing flow tests**

Use an actor fake API to assert automatic login calls only `getConfig → getStrategy`; manual and background login call `getConfig → oauth → getStrategy`; OAuth receives the device UUID and correct relogin flag; concurrent calls do not duplicate requests; invalid OAuth is not stored; OAuth failure preserves the prior session; strategy failure after OAuth preserves the new session; and logout clears session but not UUID.

- [x] **Step 2: Verify RED**

Run: `swift test --filter RemoteSessionCoordinatorTests`

Expected: compilation fails because the coordinator and API protocol do not exist.

- [x] **Step 3: Implement orchestration**

Define `RemoteAuthenticationAPI: Sendable` with the three existing async API methods and conform `IntegrationAPIClient`. Implement `RemoteLoginState` and typed `RemoteLoginError`. Guard every entry when state is `.loading`, persist immediately after valid OAuth, and publish authenticated state only after strategy succeeds.

- [x] **Step 4: Verify GREEN and commit**

Run: `swift test --filter RemoteSessionCoordinatorTests && swift test`

Expected: coordinator and full suites pass.

Commit: `feat: orchestrate remote login flows`

### Task 4: App composition and project verification

**Files:**
- Modify: `CoastWild/App/AppDelegate.swift`
- Modify: `CoastWild.xcodeproj/project.pbxproj` through `./scripts/bootstrap.sh`
- Modify: `docs/integration-plans/04-远程登录与账号迁移计划.md`
- Modify: this plan.

**Interfaces:**
- Consumes: completed identity store, session store, API client, and coordinator.
- Produces: shared remote-authentication dependencies owned by `CoastEnvironment`.

- [x] **Step 1: Compose dependencies without replacing UI yet**

Initialize the production Keychain store, identity store, session store, API client, and coordinator in `CoastEnvironment`. Keep the existing local auth UI until its separate UI task is implemented; do not migrate its accounts or data.

- [x] **Step 2: Update plan status and regenerate Xcode project**

Mark completed storage and state-machine steps in integration plan `04`, then run `./scripts/bootstrap.sh` so all new Swift sources enter the app target.

- [x] **Step 3: Run final verification**

Run: `swift test && xcodebuild -workspace CoastWild.xcworkspace -scheme CoastWild -destination 'generic/platform=iOS Simulator' -derivedDataPath build CODE_SIGN_IDENTITY=- build && git diff --check`

Expected: all tests pass, output contains `BUILD SUCCEEDED`, and diff check is empty.

- [x] **Step 4: Commit**

Commit: `feat: integrate remote session foundation`
