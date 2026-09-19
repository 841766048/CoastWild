# Shared, Pods, Auth, and Profile final review

Reviewed the latest working-tree revisions against ON01, AU01–AU05, ME01, SE01, and SE02.

## Historical finding — closed in fbe6520

### [P2] AU04 reset subtitle still does not identify the account from the recovery flow

The imported AU04 copy is “Reset the password for” followed by the account being reset. The latest implementation displays the generic “Reset the password for your local account.” and `AuthController` carries only `demoCode`, so the user cannot verify which account the code applies to. Carry the normalized recovery email into reset mode and render it with the imported subtitle hierarchy. (`CoastWild/UI/AuthController.swift:122-129`, `CoastWild/UI/AuthController.swift:149-152`, `CoastWild/UI/AuthController.swift:245-251`)

## Closed findings

- The Units field now displays both distance and temperature values, and both remain editable from its menu.
- AU05 account type is now a noninteractive information row without a false button/chevron affordance.
- ON01 and AU01–AU03 English headings, prompts, labels, placeholders, and actions now match the local JSON; AU04 title is also corrected.
- SE01 and SE02 now use `#F3F8FA` behind white form cards.
- ME01/AU05 portraits now use the imported 86 × 86 circle and 39 × 39 icon.
- ME01 stats now use a transparent ruled row with imported typography instead of a filled rounded panel.
- ME01 supplies “Your space” / “个人空间” as the back label for settings/privacy pushes.
- CocoaPods/IQKeyboardManager integration, shared `#EFF4F6` inputs, exact title metrics, approved Bold/Semibold mapping, localized toolbar title, authentication, logout, account isolation, export, and clearing flows remain connected.

## Review boundary

This was a source-only review of a dirty working tree. No build or simulator run was performed, and unrelated root changes were not modified.

## Final closure

Whole-change re-review verified fixes in `fbe6520` and `6aac98a`; no open source-review findings. Integrated execution and screenshot evidence is recorded in `verification-2026-09-20.md`.
