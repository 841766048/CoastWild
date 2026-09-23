# Version 1 without IAP Implementation Plan

> Execute with subagent-driven-development; user approved this branch strategy.

**Goal:** Ship codex/native-uikit without any first-party purchase functionality while preserving all purchase functionality on codex/native-coin-learning for version 2.

**Architecture:** Physically remove first-party payment APIs, StoreKit adapter, purchase bridge topics, restore UI and purchase analytics/config from the version-1 branch. Record that removal in Git. Merge that history into version 2 while restoring only version-1-specific removal paths to their existing version-2 state. Future ordinary merge must bring the version-2 implementation back.

**Tech Stack:** Swift, UIKit, StoreKit removal, XCTest, XcodeGen, Git worktrees.

## Global Constraints

- Main is codex/native-uikit; version 2 is codex/native-coin-learning at 1e52224.
- Do not push or merge version 2 into main for release.
- Preserve unrelated staged privacy-hero Contents.json in the original checkout.
- No hidden purchase capability or feature flag in version 1; remove first-party implementation and purchase-specific configuration/resources.
- Preserve login, configuration, privacy, general attribution, native free learning and non-payment JS features.
- Generic third-party SDK internals are not first-party integration code; check linkage and report limitations honestly.

## Task 1: Remove first-party IAP on version 1

Work ONLY in ios/.worktrees/v1-no-iap. All production and existing test edits belong here.

Files: delete App/StoreKit2PurchaseStore.swift; Core/IAPBridgeHandler.swift, IntegrationPurchaseServer.swift, ProductCatalog.swift, PurchaseCoordinator.swift, PurchaseLog.swift, PurchaseOrderMappingStore.swift; their purchase-only tests. Remove related sections of AppDelegate, AttributionAdapters, AttributionCoordinator, BridgeMessage, BusinessBridgeAction, JavaScriptCallbackEncoder, IntegrationAPIClient/DTOs/EndpointPaths/Environment/EnvironmentLoader/RuntimeConfiguration, BusinessWebController, InternalWebController, ProfileController, IntegrationConfig.plist, translations/legal text and project configuration as applicable. Keep unrelated functionality in mixed files and tests.

- [x] Add Tests/VersionOneBoundaryTests.swift before implementation: assert BridgeTopic.allCases raw values exclude OpenAppPurchase, LogPurchase, onCreateOrder, GetProductPrice, openVipService, recharge, UpdateCoins; assert production files exclude purchase adapter/API/receipt/restore implementation and config. Use source-root URL derived from #filePath for the static boundary check, scan only first-party production text, not third-party code or historical docs. Run swift test --filter VersionOneBoundaryTests and record expected RED.
- [x] Delete only purchase-only files via apply_patch. Remove references and associated mixed-file tests. Unknown former bridge topics must follow existing unknown-topic rejection, not a new no-op purchase implementation. Keep App Store review external URL behavior without StoreKit import.
- [x] Run swift test; retain all relevant non-payment tests and add a UI assertion that Profile has no restore purchase entry. Update project via xcodegen generate; root orchestrates pod install and Xcode tests.
- [x] Self-review rg results for purchase/IAP/StoreKit/recharge/entitlement/config. Document genuine unrelated matches. Report exact RED/GREEN evidence and changed files. Do not commit until root build validation, to keep one reviewed removal commit.

## Task 2: Verify V1 and preserve V2 merge behavior (root)

- [x] Run baseline and final core suite, Release simulator build, and profile/free-learning UI regression.
- [x] Review Task 1 diff with a fresh reviewer; resolve actionable findings and commit only version-1 changes on codex/native-uikit.
- [x] Use an isolated version-2 preparation worktree from 1e52224. Merge the removal commit with --no-commit; retain existing V2 versions for removal-affected paths. Keep release plan/history docs; omit V1-only boundary tests from V2. Prove original V2 production and test tree content is unchanged using git diff 1e52224.
- [x] Commit the prepared V2 merge; fast-forward original feature checkout only after checking unrelated staged asset will be unaffected. Do not stash/drop/commit that user asset.
- [x] Preflight git merge-tree main feature: require no conflicts and compare resulting production tree with V2. Run V2 core tests; record exact refs and checks in a release handoff document.
- [x] Leave main and V2 separate; report local checkout paths, commits and future merge instructions.
