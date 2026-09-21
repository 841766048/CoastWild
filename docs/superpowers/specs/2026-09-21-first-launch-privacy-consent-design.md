# First-launch Privacy Consent Design

## Goal

Require explicit privacy consent before the app can start remote authentication on a fresh installation.

## Routing and persistence

Store consent independently from onboarding and account data in the same app-scoped `UserDefaults` used by remote session state. `CoastEnvironment.showRoot()` presents `PrivacyConsentController` until consent is accepted. After acceptance it presents `RemoteLoginController`; subsequent launches skip consent. Reinstalling removes the app container and therefore requires consent again.

## Consent screen

The full-screen first-launch page explains that continuing permits the app to process device and login information. It exposes separate Privacy Policy and Terms of Service buttons and two explicit choices:

- **Agree and continue** persists consent and enters remote login.
- **Disagree and exit** keeps consent unset, performs no authentication request, and leaves the app on a blocked state with an option to reconsider.

The policy buttons use the current `IntegrationRuntimeConfiguration` snapshot so values returned by `getConfig` replace bundled URLs for later visits. Before the first login, bundled HTTPS URLs are used because `getConfig` is intentionally not called before consent.

## Network boundary

No call to `automaticLogin`, `manualLogin`, `getConfig`, or `oauth` occurs while consent is absent. The remote login controller is not constructed until consent is accepted.

## Verification

Unit tests cover consent persistence and clearing behavior. UI tests cover fresh-install gating, agreement followed by login, relaunch without repeated consent, and disagreement without exposing the login button.

