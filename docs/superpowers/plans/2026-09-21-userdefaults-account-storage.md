# UserDefaults Account Storage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Persist local account records and login state in `UserDefaults`, preserving existing Keychain users through a one-time migration.

**Architecture:** Add a small raw-data `UserDefaults` store to the cross-platform core target and keep the Security-backed legacy reader in the iOS app target. `AccountVault` owns encoding, selects separate production/test keys, and migrates legacy bytes only after a successful destination write.

**Tech Stack:** Swift 5, Foundation `UserDefaults`, Security Keychain, XCTest, CommonCrypto PBKDF2.

## Global Constraints

- Keep password storage as PBKDF2-SHA256 digest plus random salt; never store plaintext passwords.
- Keep the Keychain helper in the project.
- Preserve registration, login, logout, and recovery behavior.
- Do not modify unrelated dirty workspace files.

---

### Task 1: UserDefaults byte storage

**Files:**
- Create: `CoastWild/Core/AccountDataStore.swift`
- Modify: `Tests/CoastWildCoreTests.swift`

**Interfaces:**
- Produces: `AccountDataStore` with `load() throws -> Data?`, `save(_:) throws`, and `remove() throws`.
- Produces: `UserDefaultsAccountDataStore(defaults:key:)`.

- [x] Add tests proving save/reload/removal and key isolation with temporary `UserDefaults` suites.
- [x] Run `swift test` and verify the tests fail because the types do not exist.
- [x] Implement the minimal storage type using `UserDefaults.set`, `data(forKey:)`, and `removeObject(forKey:)`.
- [x] Run `swift test` and verify the suite passes.

### Task 2: AccountVault migration

**Files:**
- Modify: `CoastWild/App/AccountVault.swift`

**Interfaces:**
- Consumes: `UserDefaultsAccountDataStore`.
- Produces: unchanged `AccountVault(testing:)` public initializer and auth methods.
- Keeps: `KeychainAccountDataStore` as the legacy migration utility.

- [x] Replace direct Keychain persistence with production/test `UserDefaults` keys.
- [x] On missing destination data, decode legacy Keychain bytes, save them to `UserDefaults`, and only then remove the legacy item.
- [x] Treat malformed stored bytes and storage failures as `VaultError.storage`.
- [x] Build the iOS app to verify Foundation, Security, CommonCrypto, and core target integration.

### Task 3: Regression verification

**Files:**
- Modify only if required by a discovered regression.

- [x] Run all Swift core tests.
- [x] Build the CocoaPods workspace for an iPhone simulator.
- [x] Confirm the app binary no longer writes account data through `SecItemAdd` or `SecItemUpdate`; Keychain calls remain only in the migration helper.
