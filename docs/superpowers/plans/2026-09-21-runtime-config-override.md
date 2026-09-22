# Runtime Configuration Override Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace five bundled integration values with valid package-specific `app_ext_data` values after `getConfig` decrypts successfully.

**Architecture:** An `IntegrationRuntimeConfiguration` actor owns bundled defaults and publishes immutable snapshots. `IntegrationAPIClient.getConfig` applies decrypted configuration to the actor only after the complete response pipeline succeeds.

**Tech Stack:** Swift 5.9, Foundation, Swift Concurrency, XCTest.

## Global Constraints

- Bundled `IntegrationConfig.plist` values remain the fallback source.
- Only `<bundleIdentifier>:privacy`, `:terms`, `:app_id`, `:aj_token`, and `:aj_purchase_token` may override defaults.
- URL overrides must be absolute HTTPS URLs.
- Missing or invalid fields fall back independently to bundled defaults.
- Each successful response starts from bundled defaults so omitted fields cannot leave stale overrides.

---

### Task 1: Runtime configuration actor

**Files:**
- Create: `CoastWild/Core/IntegrationRuntimeConfiguration.swift`
- Modify: `CoastWild/App/AppDelegate.swift`
- Create: `Tests/IntegrationRuntimeConfigurationTests.swift`

**Interfaces:**
- Consumes: `IntegrationEnvironment`, `JSONValue`
- Produces: `IntegrationRuntimeConfiguration.init(environment:)`, `snapshot()`, and `apply(configuration:)`

- [x] **Step 1: Write failing replacement and fallback tests**

Test all five package-prefixed replacements, other-package rejection, HTTPS validation, empty-value fallback, malformed payload fallback, and reset-to-default behavior on a second response.

- [x] **Step 2: Verify RED**

Run: `swift test --filter IntegrationRuntimeConfigurationTests`

Expected: compilation fails because `IntegrationRuntimeConfiguration` does not exist.

- [x] **Step 3: Implement the actor and immutable snapshot**

Add a snapshot with `privacyURL`, `termsURL`, `appStoreID`, `adjustToken`, and `adjustPurchaseToken`. Parse only `items[name == "app_ext_data"].data`, resolve the five exact bundle-prefixed keys, validate URLs as HTTPS, and publish one new snapshot assembled from bundled defaults plus valid overrides. Initialize the actor in `CoastEnvironment` so later privacy, App Store, and Adjust consumers share it.

- [x] **Step 4: Verify GREEN**

Run: `swift test --filter IntegrationRuntimeConfigurationTests`

Expected: all runtime configuration tests pass.

### Task 2: Apply overrides after getConfig

**Files:**
- Modify: `CoastWild/Core/IntegrationAPIClient.swift`
- Modify: `Tests/IntegrationNetworkTests.swift`

**Interfaces:**
- Consumes: `IntegrationRuntimeConfiguration.apply(configuration:)`
- Produces: optional `runtimeConfiguration` dependency on `IntegrationAPIClient`

- [x] **Step 1: Write failing integration tests**

Inject a runtime configuration actor, return a valid encrypted `getConfig` response containing `app_ext_data`, and assert the snapshot changes after `getConfig`. Add a failed-`k4` case and assert the snapshot remains unchanged.

- [x] **Step 2: Verify RED**

Run: `swift test --filter IntegrationNetworkTests`

Expected: compilation fails because the client does not accept or update the runtime configuration dependency.

- [x] **Step 3: Implement post-decryption application**

Add an optional actor dependency to the client initializer. After `k4` decrypts and converts to `JSONValue`, call `await runtimeConfiguration.apply(configuration:)` before caching the derived key and returning the bundle.

- [x] **Step 4: Verify GREEN and regressions**

Run: `swift test --filter IntegrationNetworkTests && swift test`

Expected: integration and full suites pass.

### Task 3: Xcode integration and verification

**Files:**
- Modify: `CoastWild.xcodeproj/project.pbxproj` through `./scripts/bootstrap.sh`
- Modify: this plan to check completed steps

**Interfaces:**
- Consumes: completed runtime configuration implementation
- Produces: buildable iOS application target

- [x] **Step 1: Regenerate and build**

Run: `./scripts/bootstrap.sh && xcodebuild -workspace CoastWild.xcworkspace -scheme CoastWild -destination 'generic/platform=iOS Simulator' -derivedDataPath build CODE_SIGN_IDENTITY=- build`

Expected: `BUILD SUCCEEDED`.

- [x] **Step 2: Run final checks**

Run: `swift test && git diff --check`

Expected: all tests pass and diff check emits no errors.

- [x] **Step 3: Commit**

```bash
git add CoastWild.xcodeproj/project.pbxproj CoastWild/App/AppDelegate.swift CoastWild/Core/IntegrationRuntimeConfiguration.swift CoastWild/Core/IntegrationAPIClient.swift Tests/IntegrationRuntimeConfigurationTests.swift Tests/IntegrationNetworkTests.swift docs/superpowers/plans/2026-09-21-runtime-config-override.md
git commit -m "feat: apply remote runtime configuration"
```
