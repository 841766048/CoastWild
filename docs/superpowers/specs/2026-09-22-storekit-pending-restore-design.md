# StoreKit Pending and Restore Design

## Goal

Ensure that a purchase initially returned as pending can be verified after later approval, and that verified current entitlements can be restored even when no local order mapping survives.

## Order Association

Before starting StoreKit purchase, persist the server order ID under the product's pending key. When a verified transaction later arrives through `Transaction.updates`, resolve the order ID in this order:

1. Existing transaction-ID mapping.
2. Pending product-ID mapping.

When the pending product mapping is used, copy it to the transaction-ID mapping and remove the pending product mapping before yielding the transaction. The existing single-purchase guard prevents two simultaneous pending orders for the same product inside this app flow.

Cancellation removes the pending mapping. An unverified or pending result retains enough state for a later verified StoreKit update; no unverified transaction is sent to the server.

## Restore Semantics

`Transaction.currentEntitlements` is the source of truth for restorable StoreKit ownership. Every verified current entitlement is returned for server verification whether or not a local order-ID mapping exists. If a mapping exists it is included; otherwise `StoreTransaction.orderID` is `nil`, and the server verifies the signed StoreKit transaction.

Finishing a successfully verified transaction may continue deleting temporary transaction and order mappings. Restoration must never require those temporary mappings, which also allows reinstall and new-device restoration.

Unverified entitlements remain excluded. A failed server verification leaves the StoreKit transaction unfinished so a later retry remains possible.

## Components

- `StoreKit2PurchaseStore` resolves and migrates pending mappings, emits verified updates, and returns verified current entitlements with optional order IDs.
- `PurchaseCoordinator` keeps its existing contract: it passes the optional order ID to the server, updates active entitlements, and finishes only after successful server verification.
- No JavaScript Bridge payload or public purchase API changes are required.

## Verification

- Extract the order-mapping decisions into a Foundation-only helper so they can be tested without live StoreKit products or transactions.
- Test that a delayed approved transaction consumes the pending product mapping, persists the transaction mapping, and yields its order ID.
- Test that an existing transaction mapping wins and does not consume an unrelated pending mapping.
- Test that restore includes verified entitlements with `orderID == nil` when no local mapping exists.
- Preserve existing purchase ordering tests and run the full Swift suite plus an iOS simulator build.

## Scope

This change does not configure App Store Connect products, perform sandbox purchases, change server endpoints, add subscriptions, or alter receipt/JWS logging.
