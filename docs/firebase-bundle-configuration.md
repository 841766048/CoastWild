# Firebase configuration for the production bundle identifier

- Firebase project: `coast-wild-20260915` (existing project retained).
- Registered iOS bundle identifier: `com.huankecontact.coastwild`.
- Registered Firebase app ID: `1:396075139301:ios:33e5decb0b119794cdd40c`.
- Configuration: `CoastWild/Resources/GoogleService-Info.plist`, retrieved from Firebase with `apps:sdkconfig IOS` for this app ID.
- No database, authentication users, storage, security rules, backend environment, Apple Team ID or provisioning profiles were migrated or changed.

The configuration is shared across `main`, `codex/native-uikit` and `codex/native-coin-learning`. The first two already integrate Firebase and bundle this resource. The second-version branch currently has no Firebase SDK or initialization: its copy is configuration-only, not a new Firebase integration or a runtime cloud-sync feature. Adding the SDK and linking the resource there remains a separate task.

Changing the bundle identifier or signing team does not itself guarantee access to an old installation's Keychain identity. Recovery of existing private notes must be verified separately on a device; retaining the Firebase project does not guarantee identity continuity.
