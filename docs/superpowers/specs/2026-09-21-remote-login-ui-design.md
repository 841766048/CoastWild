# Remote Login UI Design

## Goal

Replace the pre-release email/password account UI with one device-based remote login portal. App launch, manual login, logout, and local ledger activation must use `RemoteSessionCoordinator` and the remote `userId`.

## Routing

`CoastEnvironment.showRoot()` no longer checks `AccountVault`. When no remote user has been activated in the current process it presents `RemoteLoginController`. That controller performs automatic login once after appearing:

- `.authenticated`: activate `CoastStore` with the remote `userId`, set onboarding complete, and replace the root with the main tabs.
- `.idle`: show the enabled device-login button.
- `.failed`: show a recoverable error and keep the device-login button enabled.

The main tab construction moves into a dedicated `showMainInterface()` method so successful automatic and manual login use the same route. Existing local vault records and test ledgers are ignored and are not migrated.

## Login Screen

The screen reuses the existing coast image, typography, spacing, and primary button components. It contains:

- Product image and “Welcome” heading.
- Short copy explaining that the device will be used for secure sign-in.
- One primary “Continue” / “快捷登录” button with accessibility identifier `auth.remote.submit`.
- A compact activity indicator and status label.
- Existing privacy and terms entry points using the runtime configuration URLs when those consumers are connected.

Email, password, registration, recovery, and demo-account copy are removed from the reachable app flow. The old controller code may be deleted once tests no longer reference it.

Manual login disables the button before starting and restores it on failure. Successful login activates an empty ledger for a previously unseen remote `userId`; `CoastStore.activate` already provides this behavior.

## Connectivity and Errors

A small `ConnectivityMonitoring` abstraction wraps `NWPathMonitor` and publishes the current reachable state on the main actor.

- Offline failure: show one alert titled “No Network Connection” / “无网络连接” with Cancel and Open Settings actions.
- The Open Settings action opens `UIApplication.openSettingsURLString`.
- If connectivity becomes available while the alert is visible, dismiss it automatically.
- Other login failures display an inline “Login failed.” / “登录失败，请重试。” message.
- Repeated taps and automatic/manual overlap cannot start duplicate requests; both the controller and coordinator enforce this.

## Logout

The account screen describes the account as remote instead of local preview. Logout performs these operations in order:

1. Await `RemoteSessionCoordinator.logout()`.
2. Activate `CoastStore` with `nil` to remove the active ledger from memory.
3. Replace the root with a fresh `RemoteLoginController`.

The device UUID and per-user ledger file remain on disk. No old bearer token is available to subsequent API requests.

## UI Testing

UI tests must not depend on the live service. Under the existing `--ui-testing` launch argument, `CoastEnvironment` injects a deterministic in-process `RemoteAuthenticationAPI` fixture. This fixture is reachable only through the UI-testing composition path and is not selected in normal launches.

The UI suite verifies:

- Fresh launch displays the remote-login button and no email/password fields.
- One tap enters the main tabs and activates the fixture remote user.
- Logout returns to the remote-login screen and removes the tab bar.
- Relaunch with a persisted fixture session uses automatic login.
- Repeated taps do not duplicate the login transition.

Core coordinator tests remain responsible for network/API ordering and failure persistence. Simulator build and the focused UI flow are the final acceptance checks.
