# Firebase configuration for the production bundle identifier

Updated: 2026-10-10.

- Firebase project: `coast-wild-20260915` (existing project retained).
- Registered iOS bundle identifier: `com.huankecontact.coastwildapp`.
- Registered Firebase app ID: `1:396075139301:ios:b7f2da0f3663191ecdd40c`.
- Configuration: `CoastWild/Resources/GoogleService-Info.plist`, downloaded with Firebase CLI `apps:sdkconfig IOS` for the new app ID and verified against the official download.
- Firebase does not support changing an existing iOS registration's Bundle ID. A new iOS registration was created in the same project. The previous registrations remain intact.
- No databases, Authentication users, storage files, security rules, Apple Team ID or provisioning profiles were changed.

The configuration is synchronized across the local working trees for `main`, `codex/native-uikit` and `codex/native-coin-learning`. The first two already integrate Firebase. The second-version branch's plist remains configuration-only: this change does not install the Firebase SDK, change its authentication implementation, or remove Web/JS, Adjust or purchase functionality.

Apple registration, provisioning profiles and the App Store Connect record must separately match the new Bundle ID. Firebase configuration validation passing does not prove device signing, App Store upload, or runtime authentication works.

Changing Bundle ID creates a different app identity. Existing installation data and Keychain sessions do not automatically migrate. Keeping the same Firebase project retains backend data but does not guarantee the new installation can recover the old user's UID or private notes.

## Previous registration (retained)

- Bundle ID: `com.huankecontact.coastwild`.
- Firebase app ID: `1:396075139301:ios:33e5decb0b119794cdd40c`.
