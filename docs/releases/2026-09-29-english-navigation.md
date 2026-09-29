# English-only app presentation and arrow-only back navigation

## Scope

Updated both `codex/native-uikit` and the existing `codex/native-coin-learning` worktree. Changes remain local and uncommitted; no merge, push, deployment or real payment was performed.

- App-owned UI uses English, including legacy installations whose saved language was Chinese. Region, units, interests, user-authored notes, titles and photo references remain unchanged.
- Removed the language selector, the Welcome language-settings row and obsolete wording promising configurable language.
- Removed the app's bundled Chinese legal HTML and Chinese InfoPlist localization. Legal titles, local resources and configured legal URLs select English.
- Existing navigation controller uses native minimal back-button display. No visible Back or previous-page title, including V2 coin screens. Native accessibility labels and interactive pop remain.
- V1/V2 capability boundaries remain unchanged. V2 retains Web/Bridge/ATT/Adjust/IAP; cloud/wire multilingual dictionaries and user-authored text are not deleted. Server-owned H5 content is not translated by this change; its production bootstrap locale is English.

## Verification

- Regression tests first failed in both branches: 3 tests, 10 expected assertions each. They cover persisted language migration, preserving preferences and Chinese user text/photos, write normalization and English legal selection.
- V1 core: 186 passed, with the existing local public manifest supplied and no skips.
- V2 core: 289 passed, including the version capability boundary checks.
- V1 UI: English settings/back, English privacy under a Chinese system locale, rapid tab/push/pop/dialog and interactive back scenarios passed (3 selected tests).
- V2 UI: English settings/back and privacy under a Chinese system locale passed (2 selected tests); all 6 native coin scenarios passed using test purchase fixtures, not real Apple payment.
- Screenshot inspected: nested Preferences back control is an arrow without text.
- Independent review passed after restoring the exact pre-task V1 manual signing/team/profile configuration. `project.yml` now preserves those existing settings on regeneration. V2 existing Pods integration remains intact.

Initial privacy UI test mistakenly selected Terms by index while asserting the Privacy title; corrected to select the Privacy Policy link by label and reran successfully. Existing tests expecting Chinese were migrated without dropping their scenarios.

## Build and resource notes

Release simulator builds are verified separately for each branch. App-level Chinese localization/legal resources are absent from fresh products. Third-party SDK bundles may retain their own localization resources; the app date picker explicitly selects English. Existing build warnings are not claimed resolved.

Old generated app products were moved to `/tmp/coast-english.p30QGO/` before rebuilding so stale localization files could not mask the resource removal. Pre-task snapshots, exact test logs, results and screenshots are also stored there; no user app data was removed. Chinese source comments and unreachable legacy bilingual helper strings remain outside the user-visible presentation scope.
