# Runtime Configuration Override Design

## Goal

After `getConfig` succeeds and its `k4` payload is decrypted, replace five runtime values with package-specific values from `app_ext_data`:

- `privacyURL`
- `termsURL`
- `appId`
- `ajToken`
- `ajPurchaseToken`

The bundled `IntegrationConfig.plist` remains the fallback source.

## Source Mapping

For bundle identifier `<pkg>`, read these `app_ext_data` keys:

| Runtime field | Server key |
| --- | --- |
| `privacyURL` | `<pkg>:privacy` |
| `termsURL` | `<pkg>:terms` |
| `appId` | `<pkg>:app_id` |
| `ajToken` | `<pkg>:aj_token` |
| `ajPurchaseToken` | `<pkg>:aj_purchase_token` |

Only the `items` entry whose `name` is `app_ext_data` is eligible. Unprefixed values and values belonging to other packages are ignored.

## Architecture

Add an `IntegrationRuntimeConfiguration` actor initialized from `IntegrationEnvironment`. It owns an immutable snapshot containing the five replaceable values. Consumers obtain the latest snapshot asynchronously rather than reading mutable global variables.

`IntegrationAPIClient` receives the runtime store as an optional dependency. After it has successfully decrypted and parsed `getConfig`, it applies the configuration to the store before returning the response bundle. Existing callers that do not supply a store remain source-compatible.

## Validation and Fallback

- Missing, non-string, empty, or whitespace-only server values do not replace defaults.
- `privacyURL` and `termsURL` replace defaults only when they are valid absolute HTTPS URLs.
- Valid fields are applied independently; one invalid field does not reject the other valid replacements.
- A failed request, failed decryption, or malformed `app_ext_data` leaves the last valid snapshot unchanged.
- Repeated successful responses replace the previous runtime values, again using bundled defaults for fields missing from that response. This prevents stale values from a previous configuration version surviving unintentionally.

## Data Flow

1. Load `IntegrationEnvironment` from `IntegrationConfig.plist`.
2. Initialize `IntegrationRuntimeConfiguration` with the five bundled defaults.
3. Request and decrypt `getConfig`.
4. Find `items[name == "app_ext_data"].data`.
5. Resolve package-prefixed values for the current bundle identifier.
6. Validate and atomically publish a new snapshot.
7. Privacy/terms screens, App Store links, and Adjust initialization read the runtime snapshot when those integrations are implemented.

## Testing

- All five valid package-prefixed values replace defaults.
- Missing values fall back to bundled defaults.
- Empty strings, invalid URLs, HTTP URLs, other-package keys, and malformed payloads are ignored.
- A second configuration response resets omitted values to bundled defaults.
- `IntegrationAPIClient.getConfig` applies replacements only after successful `k4` decryption.
- Existing encryption, network, retry, and build tests remain green.
