# First-launch Privacy Experience

## Approved flow

On a fresh installation, show the approved HF-v1.4 full-screen privacy experience before onboarding, authentication, or app content. The user can open native Terms of Use and Privacy Policy pages. Continuing requires an explicit unchecked-to-checked agreement action. Declining opens the approved bottom sheet and leaves the user behind the privacy gate unless they agree.

## Persistence

Store a versioned acceptance integer in `UserDefaults`. A future policy version can require consent again by increasing the current version. Keep production and UI-test keys separate. Resetting UI-test data resets only the test consent key.

## Permissions and platform behavior

The privacy screen never requests Photos or Notifications access. Those prompts remain contextual. iOS apps cannot terminate themselves, so “Exit app” dismisses the sheet and keeps the privacy gate visible.

## Accessibility and localization

All actions have accessible labels and identifiers, support Dynamic Type, and provide Simplified Chinese and English copy. Colors maintain readable contrast and controls use at least 44-point touch targets.
