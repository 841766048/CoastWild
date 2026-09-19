# Bounded re-review — fix wave fbe6520 + a0c6908 / 744cb12

## Current outcome

All five original findings and the follow-up selection regression are now closed in source, including commit `6aac98a`. No remaining actionable Critical, Important, or Minor findings in this bounded review.

### Closed follow-up: visible activity selection indicator

`CoastWild/UI/TripsController.swift:448-459` now chooses the 1 pt border color from the selected state: brand `#075E73` for selected, `#DFE9ED` otherwise. Selection already rerenders the cards, so the chosen item becomes visibly distinct. Explicit accessible labels/identifiers and selected traits remain intact. Inspected commit `6aac98a` and current source; this closes the regression. The fix report records fresh parser and diff checks. Root owns the pending UI run and final workspace build.

## Original findings closed

1. **Custom card accessibility:** trip hero/picker/linked journal and journal list buttons now have explicit labels and stable identifiers; timeline options are contextually labelled. Explore/Learn commit a0c6908 applies the same repair to its custom cards.
2. **Journal linked experience:** the control is now attached, shown for a current association, updated on change, and hidden when cleared. It opens the existing change/clear menu.
3. **TR03 geometry/assets:** rows are grouped with zero spacing, each 64 pt high. Badge colors match the source and existing wave/hike/camp assets are centered at 24 pt inside 42 pt circles.
4. **Recovery account:** normalized recovery email is passed to reset mode and displayed under the subtitle with `auth.recovery.email`.
5. **Units selected state:** selected distance is passed separately from the distance/temperature summary, restoring the checkmark.

Configured-button typography changes in 744cb12 apply the intended fonts through configuration transformers; no new correctness issue identified there.

## Evidence boundary

Read current source, /tmp/coast-review-fixes.diff, and docs/figma-final-fix-report.md. No source/index/HEAD changes or builds by reviewer. Observed root logs: /tmp/coast-core-verified.log records 23 tests, zero failures; /tmp/coast-bootstrap-verified.log records generated project and successful CocoaPods integration. Extended UI verification is still running in /tmp/coast-ui-final-pass.log and is not claimed complete. Full all-screen pixel parity remains outside this source-only review.

---

# Original review (historical; closure status above supersedes it)

# Whole-change senior review — CocoaPods / HF-v1.2

Reviewed baseline `817fa9f` through current source (including uncommitted shared/content fixes), `/tmp/coast-full-review.diff`, the implementation plan, prior per-area reviews, and targeted original import JSON. Source/index/HEAD were not modified. No builds were run by this reviewer.

## Critical

None found.

## Important

### 1. Custom Trips/Journal buttons lack accessible names

`CoastWild/UI/TripsController.swift:396`, `:448`, `:457` and `CoastWild/UI/JournalController.swift:510` return custom UIButtons with only nested UILabels, no UIButton title or accessibilityLabel. The new trip hero, activity picker cards, linked journal cards, and journal list cards therefore omit the explicit accessible names the previous shared `row` supplied. Root reproduced the equivalent construction in Learn as a missing named button in XCUITest. Set the card button's localized accessibilityLabel (title plus short metadata), an appropriate stable identifier, and selected traits for picker selections. The image-only timeline options button at `TripsController.swift:434-436` also needs a localized contextual name. Verify card navigation through accessibility on the simulator.

### 2. Linked experience becomes invisible in the journal editor

`CoastWild/UI/JournalController.swift:129-131` creates `activityButton` but never adds it to the hierarchy; `:195-197` updates only this invisible button's accessibility value. The linking action still exists inside the trip menu, so selecting an experience persists a relationship with no visible confirmation; reopening an existing linked entry also cannot show what is linked. Preserve the reference's default single trip group, but expose the current experience through a visible selected summary when set (or a clearly labelled/checkmarked linking menu), and support clearing it. Remove the orphan button or attach a real control.

### 3. TR03 timeline still differs materially from the reference

`CoastWild/UI/TripsController.swift:190-195` adds each 64 pt timeline row directly into the outer stack whose spacing is 14. Reference en-TR03 badges start at y=449.578125, 513.578125, and 577.578125: a 64 pt pitch. The current layout has 78 pt pitch, accumulating extra gaps independently of device safe-area differences. Group timeline rows in a zero-spacing vertical stack and preserve spacing around the whole group.

Also `TripsController.swift:428-430` fills the badge with a content photo on `#F3F8FA`. The original JSON specifies a 42 pt colored circle with a centered 24 pt category SVG: hike/camp `#F9EDD5`, surf `#DFF0F4`, icon stroke `#075E73`. Pass the category key and use the original category icon/color rather than the destination photograph.

### 4. AU04 omits the account being reset

`CoastWild/UI/AuthController.swift:149-152` renders a generic local-account subtitle. The original AU04 provides “Reset the password for” followed by the recovery account. As confirmed by the final shared review, the controller only receives the demo code. Carry the normalized recovery email into reset mode and display it with the reference subtitle hierarchy so users can verify the target account. See constructor `:122-129` and recovery transition near `:245-251`.

## Minor

### 5. Distance menu loses its selected state after Units summary fix

`CoastWild/UI/ProfileController.swift:76-77` determines selected actions by comparing each action label with `value`. At `:84`, `value` is now a composite such as `Miles · °F`, which matches neither `Miles` nor `Kilometers`; neither distance option is checked. Pass a distinct selected value/index or explicitly create distance action states from `distanceUnit`. The composite displayed summary is useful and should remain.

## Assessment and verification boundary

CocoaPods setup, lockfile/module imports, keyboard manager initialization, toolbar localization, and bootstrap regeneration are coherent. Previous major omissions (linked trip journals, journal edit/delete row, grouped editor fields, soft backgrounds, profile portraits/stats, inert account row, and English onboarding/auth copy) are addressed except where listed above. Existing core tests and workspace build were reported passing by root; the current UI rerun is still root-owned, with the equivalent Learn accessibility fix in progress.

Recommend closing the Important findings and rerunning the existing functional/keyboard UI flow before acceptance. This source review does not establish all-screen pixel parity. Reported timeline differences are intrinsic geometry/assets, not changes in system safe-area height; normal device safe-area adaptation remains allowed by the plan.

## Root integration evidence

Final workspace build/test succeeded: 3 UI tests, 0 failures; 23 core tests, 0 failures. The nested experience selector test waits for the named sheet and hittable action before selecting. Final screenshots include the visible linked activity and recovery email. See `verification-2026-09-20.md`.
