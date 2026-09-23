# Native coin learning Implementation Plan

> **For agentic workers:** Use subagent-driven-development or executing-plans to implement task-by-task.

**Goal:** Complete the approved native purchase → local coins → guide unlock → reading loop.

**Architecture:** A durable device-local wallet is the single authority for native coin balance, transaction deduplication and unlocked guide IDs. PurchaseCoordinator fulfills only after server verification and persists before finishing StoreKit transactions. UIKit screens use the existing environment and purchase pipeline.

**Tech Stack:** Swift 5, UIKit, StoreKit 2, Foundation atomic JSON storage, XCTest.

## Global Constraints

- Work on codex/native-coin-learning; do not merge or push.
- Preserve the staged privacy-hero Contents.json change.
- Product 1coins_19 credits 100 coins; Coastal Camping costs 30 coins.
- Start at zero; no production fake credits; display App Store localized price.
- Local device storage; no cross-device/reinstall restoration promise.
- Recharge never auto-spends. Reopening owned guides never charges again.
- Match approved docs/designs/native-coin-purchase images; sheet backgrounds reuse topic detail; Back to guide for topic-origin purchase; remove Preview only production copy.
- Preserve existing free learning material and other bridge products.

### Task 1: Durable wallet and purchase fulfillment

Files: create Core/LocalCoinWallet.swift and Tests/LocalCoinWalletTests.swift; modify Core/PurchaseCoordinator.swift and add focused purchase-fulfillment tests.

Interfaces: LocalCoinWallet actor init(fileURL: URL); snapshot() throws -> CoinWalletSnapshot with balance:Int, unlockedGuideIDs:Set<String>, entries:[CoinWalletEntry]; unlock(guideID:String) throws; fulfill(_ transaction:StoreTransaction) async throws. Snapshot loading must fail closed on corruption, never overwrite invalid data. Entries expose id, title, amount, date. Recognized product is 1coins_19; guide coastal-camping costs 30.

- [x] RED: Write tests: initial zero; fulfill same transaction twice yields100 and one entry; reopen file retains100; unlock yields70 and one owned ID; repeat unlock stays70; insufficient leaves snapshot unchanged; unknown product no credit; unknown guide rejected; write failure no mutation; corruption no reset; concurrent duplicates credit once.
- [x] GREEN: Implement actor-serialized atomic file persistence and immutable next-state writes, dedupe transaction IDs in same durable snapshot as credit, fixed trusted SKU/guide catalog.
- [x] RED: Add PurchaseCoordinator tests proving verify → fulfill → finish, failure before finish, updates/restore fulfillment and pending/recovery status blocking repeated purchases.
- [x] GREEN: Add optional fulfillment dependency with backward-compatible default; use all verified transaction paths; ensure concurrent updates/purchase cannot bypass dedupe. Provide UI-readable pending state and explicit retry for unfinished verification without another purchase.
- [x] Run swift test and record RED/GREEN evidence in docs/superpowers/plans/native-coins-core-report.md.

### Task 2: Native UI and environment integration

Files: App/AppDelegate.swift, UI/LearnController.swift; create UI/CoinComponents.swift, UI/CoinPurchaseController.swift, UI/CoinWalletController.swift, UI/CoinGuideController.swift, Core/CoinGuide.swift, App/NativeCoinPurchaseModel.swift; add UITests/NativeCoinUITests.swift.

- [x] Write UI tests first: Learn entry exists; zero-balance unlock offers recharge; test purchase credits100; returning does not unlock until confirmation; confirming yields70; all4 chapters readable; relaunch keeps balance and unlock; free library still accessible.
- [x] Run new test against unchanged app and capture missing-entry failure.
- [x] Implement environment-shared wallet and catalog/purchase model; debug-only deterministic test store and server use real coordinator and wallet.
- [x] Implement approved catalog/detail/sheet/wallet/purchase/confirming/success/reading screens with accessibility identifiers and useful four-chapter content. Keep old free library accessible.
- [x] Price load failure supports retry; cancelled/failed payment leaves balance alone; verification pending blocks repurchase and supports retry/background completion.
- [x] Run xcodegen + pod install if needed for new source files; simulator build and focused UI tests. Record screenshots for visual review.

### Task 3: Review and handoff

- [x] Full swift test; focused simulator UI tests including cancellation/failure and relaunch.
- [x] Review financial data mutations and original JS bridge compatibility.
- [x] Compare simulator screenshots against approved layouts and fix meaningful differences.
- [x] Record actual checks and sandbox limitations; keep feature branch unmerged.
