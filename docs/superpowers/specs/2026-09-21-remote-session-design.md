# Remote Session Design

## Goal

Replace the pre-release local email/password account flow with device-based remote authentication. The app has not shipped, so existing accounts and data are test-only and require no migration, import, backup, or compatibility path.

## Scope

This feature provides device identity storage, remote session persistence, and a coordinator for automatic, manual, and background login. It does not implement WebView presentation, JS Bridge callbacks, account deletion, IAP, or attribution.

The existing local `AccountVault` remains temporarily available until the UI integration task replaces it. No production code copies or rebinds its test accounts or ledgers.

## Device Identity

`DeviceIdentityStore` resolves one stable UUID in this order:

1. Return the nonempty value under `uuidKey` in UserDefaults.
2. Otherwise read `{bundleIdentifier}_UUID` from Keychain, write it back to UserDefaults, and return it.
3. Otherwise generate a UUID, write it to both stores, and return it.

The Keychain item uses `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Dependency-injected UserDefaults, Keychain access, and UUID generation keep the behavior deterministic in tests. Logout does not remove the device UUID.

## Remote Session

`RemoteSession` is a Codable value containing the complete OAuth response needed by later requests, including the bearer token, user identifier, numeric `isFirstRegister`, and the original response object. `isFirstRegister` is true only when its numeric value equals `1`.

`RemoteSessionStore` persists the session under `LanlinLoginData`. Reading malformed or incomplete data returns no session rather than publishing a partial login. Clearing a session removes both the persistent value and the actor's current snapshot.

No legacy account data is migrated. A successful first remote login creates or activates an empty local ledger keyed by the remote `userId` during the later UI integration task.

## Login Coordinator

`RemoteSessionCoordinator` is an actor with these states:

- `idle`
- `loading`
- `authenticated(RemoteSession, strategy)`
- `failed(RemoteLoginError)`

Only one login operation may run at a time. A second request received while loading returns the current loading outcome without starting duplicate API calls.

### Automatic Login

When a complete persisted session exists, run:

1. `getConfig` with the persisted request session.
2. `getStrategy` with the persisted request session.

Automatic login never calls OAuth. If no complete session exists, remain idle so the UI can show the manual login entry.

### Manual Login

Run:

1. `getConfig` anonymously to derive the encryption key and apply runtime configuration.
2. Resolve the device UUID and call OAuth with `oauthType = "4"`. The UUID is the OAuth token; it is not a session token.
3. Decode and validate the OAuth response, persist the complete session, then call `getStrategy` with the new session.

The `relogin` request value is derived from the persisted `logindKey`. A successful manual login records this flag so later device logins use `relogin = "1"`.

### Background Login

Background login uses the same three-step pipeline as manual login and returns the new session plus strategy to its caller. WebView loading UI, review-package suppression, and the `backgroundLoginSuccess` JavaScript callback belong to the later WebView and Bridge tasks.

## Failure and Logout Semantics

- Configuration, OAuth, decoding, and strategy failures publish a typed failed state.
- An OAuth response without a nonempty token or user identifier is invalid and is not persisted.
- A failed OAuth request leaves any previously valid session unchanged.
- A strategy failure after a newly successful OAuth leaves the new session persisted, allowing the next launch to use automatic login.
- Logout clears the persistent and in-memory remote session immediately. It does not clear the device UUID or delete local business data.
- Network-specific UI such as alerts, settings links, and automatic dismissal is deferred to UI integration.

## Testing

Tests cover:

- UserDefaults hit, Keychain recovery, UUID generation, and Keychain accessibility.
- Complete session round-trip, malformed data rejection, and logout clearing.
- Numeric `isFirstRegister` semantics.
- Automatic two-step login and absence of OAuth.
- Manual and background three-step ordering.
- Duplicate-login suppression.
- Invalid OAuth response, request failure, and strategy failure persistence behavior.
- Logout invalidating the request session while retaining device identity.

All network behavior uses protocol-backed fakes; tests do not access the live service.
