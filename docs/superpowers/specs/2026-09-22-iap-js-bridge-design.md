# IAP JS Bridge Design

## Goal

Expose the existing native StoreKit 2 purchase implementation to the trusted business WebView without moving purchase, verification, or entitlement logic into the WebView layer.

## Architecture

Add an `IAPBridgeHandler` between `BusinessWebController` and the existing `ProductCatalog` and `PurchaseCoordinator`. `BusinessWebController` continues to decode and validate `BridgeMessage` values. The handler accepts only the supported IAP messages and returns typed callback commands to the controller.

The handler does not access StoreKit, networking, sessions, or WebKit directly. Those concerns remain behind the existing purchase abstractions. This keeps the adapter deterministic and unit-testable.

## Message Flow

### Product prices

1. JavaScript sends `GetProductPrice` with validated product identifiers.
2. `IAPBridgeHandler` loads localized products through `ProductCatalog`.
3. The handler returns the documented `{data: [{id, localPrice, currencyCode}]}` payload.
4. The controller invokes the existing price callback through `JavaScriptCallbackEncoder`.

Missing product identifiers are omitted from `data`, matching the current catalog DTO. A complete query failure produces a structured error callback and never fabricates a price.

### Purchase

1. JavaScript sends `OpenAppPurchase` with `goodsCode`, `paySource`, and `invitationId`.
2. The handler maps the payload to `PurchaseRequest` and invokes `PurchaseCoordinator`.
3. Purchased, pending, cancelled, and failed outcomes are mapped to explicit callback payloads.
4. The coordinator remains the only component allowed to finish a transaction or activate an entitlement.

### Purchase log

`LogPurchase` is converted to a structured native log event. Receipt and signed transaction data are never included. Logging failure does not change purchase state.

### Restore purchases

Restore remains a native account-screen action because the documented Bridge topics contain no restore command. It continues to use the same `PurchaseCoordinator`, so restored entitlements and JavaScript-initiated purchases share one source of truth.

## Integration

`CoastEnvironment` owns the handler dependencies. A business WebView receives an IAP message closure that delegates to the handler and then sends the resulting callback with the controller's existing safe JavaScript encoder. Unsupported non-IAP messages remain available for later handlers.

Only trusted main-frame messages accepted by `BridgeRouter` can reach the handler. The adapter does not weaken the existing host or frame checks.

## Error Handling

Invalid payloads continue to be rejected during Bridge decoding. Runtime failures are converted to stable error codes suitable for JavaScript branching; error messages do not expose receipts, tokens, order identifiers, or internal server responses. Duplicate in-flight purchase requests for the same handler are rejected to prevent overlapping StoreKit sheets.

## Testing

Unit tests cover price success and failure, all purchase outcomes, log redaction, unsupported messages, and duplicate purchase rejection. Existing Bridge tests continue to cover payload validation and callback escaping. The final verification includes the full Swift test suite and an iOS simulator build.
