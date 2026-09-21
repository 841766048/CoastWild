# First-launch Privacy Consent Design

## Goal

Restore the previously implemented first-launch privacy experience and place it before remote authentication.

## Existing visual experience

The app reuses the established full-screen privacy page: coastal hero artwork, warm paper background, account/photo disclosure rows, explicit checkbox, linked User Agreement and Privacy Policy text, validation copy, and the existing “Not now” bottom sheet. No replacement visual design is introduced.

## Routing and persistence

Consent is stored as a version integer in app-scoped `UserDefaults`. Increasing the current policy version requires renewed consent. `CoastEnvironment.showRoot()` shows the privacy page until the current version is accepted, then transitions to `RemoteLoginController`. Logout does not clear consent; reinstalling clears the app container and requires it again.

## Legal documents

The restored `LegalWebController` uses the current `IntegrationRuntimeConfiguration` privacy and terms URLs. Remote failure falls back to the bundled Chinese or English HTML documents. Web content runs without JavaScript or persistent website data.

## Network boundary

The remote login controller is not constructed before consent, so automatic login, `getConfig`, and `oauth` cannot begin while consent is absent.

## Verification

Unit tests cover versioned persistence. UI tests cover the original layout identifiers, unchecked validation, legal navigation, the “Not now” sheet, acceptance, remote login, and relaunch without repeated consent.

