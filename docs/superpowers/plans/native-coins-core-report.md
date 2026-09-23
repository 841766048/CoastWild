# Native coins core implementation evidence

## Scope and API

- `LocalCoinWallet(fileURL:)` is an actor and implements `PurchaseTransactionFulfilling`.
- `snapshot() throws` returns balance, unlocked guide IDs and dated signed ledger entries. `unlock(guideID:) throws` debits the trusted `coastal-camping` price of 30 once. `fulfill(_:) async throws` credits 100 only for `1coins_19` and deduplicates by transaction ID.
- `PurchaseCoordinator` adds optional `fulfillment:` without changing existing initializer callers or `PurchaseError` cases.
- `pendingPurchases()` returns public `PendingPurchase.productID` / `.transactionID`. Empty transaction ID means StoreKit approval is pending. `retryPendingPurchases()` retries retained transactions and returns successful entitlement snapshots. `purchase` returns `.pending` before creating another order for an unresolved or in-flight product.

## Persistence and financial ordering

Wallet reloads its JSON file before each operation; a missing file starts at zero. Invalid JSON, unsupported schema, inconsistent ledger/balance/dedupe/ownership, and filesystem errors fail closed. Mutation uses a next-state value, then atomic replacement; no in-memory balance can get ahead of a failed write. Credit, transaction ID and ledger entry are persisted together. Guide debit and ownership are persisted together. Actor isolation serializes operations on the environment-shared wallet.

All purchase, restore and transaction update paths run server verification → active-entitlement guard → fulfillment persistence → entitlement update → StoreKit finish. Failures retain transaction data for explicit retries; StoreKit transactions remain unfinished for relaunch delivery. Concurrent same-transaction processing shares its current verification task; the durable wallet also deduplicates repeated delivery after completion or relaunch. Unknown products remain handled by existing bridge entitlements and do not credit the native wallet.

## RED / GREEN evidence

2026-09-23, local Swift package:

1. Added wallet tests against the missing API: compiler reported `cannot find LocalCoinWallet` (API establishment only).
2. Added API skeleton with no persistence/fulfillment: `swift test --filter LocalCoinWalletTests` executed 6 tests with 12 expected assertion failures, including zero instead of 100, missing ownership, missing rejection and corruption handling.
3. Implemented wallet atomic persistence and trusted catalog.
4. Added coordinator fulfillment tests plus inert optional API: `swift test --filter PurchaseFulfillmentTests` executed 3 tests with 11 expected assertion failures. Recorded events were `[verify, finish]` instead of `[verify, fulfill, finish]` on all 3 paths; retry/pending/duplicate-purchase assertions also failed.
5. Implemented coordinator integration and retry state: full `swift test` passed 275 tests.
6. Added extra regression checks for malformed but decodable ledger, retryable restore/update failures, concurrent purchase/restore/update and repeated delivery after wallet/coordinator reconstruction. Final `swift test` passed **278 tests, 0 failures**, including 7 wallet and 5 fulfillment tests. Existing bridge and purchase tests remain passing.

## Limits and integration notes

- Use one environment-shared wallet actor per file. Separate processes or independently instantiated concurrent writers are not coordinated by a filesystem lock.
- Pending coordinator memory is reconstructed from StoreKit unfinished transaction delivery on launch; the existing StoreKit adapter enumerates `Transaction.unfinished` before live updates. Finished consumable purchase history is not a reinstall/cross-device restoration mechanism.
- Ask-to-buy approval state is held during this app session until a successful transaction update arrives; retry operates on transactions already received, not on approvals that have no transaction yet.
- Actual StoreKit sandbox/server checks and simulator UI verification belong to app integration. No production credit injection was added.

## Review follow-up (2026-09-23)

- Added goods-code → StoreKit SKU alias tracking. Pending approval is keyed by actual SKU, allowing a successful update to clear it. Known request aliases check unresolved transactions before order creation; newly resolved aliases check again before presenting StoreKit purchase. SKU-level in-flight claims prevent two known/differing request aliases from opening payment simultaneously.
- An explicit inactive-entitlement server rejection now removes its pending and approval blockers while preserving the existing error/no-finish behavior; inactive restored entitlements do not permanently block a future purchase.
- Replaced the directory-based write-error test (which exercised loading) with an internal injected writer. The test starts from valid persisted balance 100, allows decoding, fails precisely at persistence for both credit and unlock, verifies byte-identical storage and unchanged snapshot, and successfully retries the previously failed transaction using the normal atomic writer.
- RED: 3 new coordinator regressions produced 7 assertion failures (mapped approval never cleared, mapped pending re-created order, inactive restore blocked future purchase). GREEN: all 8 fulfillment tests pass.
- RED: revised write-failure test with an inert writer seam produced 5 assertion failures (writes succeeded, wallet changed, bytes changed). GREEN: wired writer at persistence boundary; final full `swift test` passes **281 tests, 0 failures**.
- Remaining integration caveat: the existing transaction update stream does not signal when initial unfinished enumeration is complete. Starting the observer early reduces but does not formally close the relaunch race before pending transactions are delivered. A store readiness/unfinished enumeration API or durable pending journal would be needed to gate purchase against that interval.
