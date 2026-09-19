# UIKit native app review — follow-up

Date: 2026-09-19. Reviewed current source and updated `native-review.diff` through `18e1ab2`, including `ec6a3aa` and `8e320ea`, plus `ui-fix-report.md` and `core-report.md`. This is a targeted static re-review; no tests were rerun. The core report records 23 passing tests. Root is running the final UIKit smoke suite, including journal regression coverage.

## Verdict

**Spec: substantially implemented for the local demo, with the minor mapping deviations below. Quality: all material findings from this review are resolved in the reviewed code; no remaining P1/P2 finding. Final runtime sign-off remains subject to the root’s running UI suite.** Root auth gating and per-account persistence remain in place; no concrete authentication bypass was found. Local recovery is explicitly labeled and does not claim to send email. Native UIKit and original artwork references are retained. Pixel-level HF-v1 fidelity is outside this code review and requires the root screenshot comparison.

## Final targeted re-review (`18e1ab2`)

Both remaining P2 paths are fixed:

- `CoastWild/UI/JournalController.swift:263–270`: Empty new-editor cancellation checks whether a persisted draft exists, deletes it before navigation, and returns without marking finished or popping if saving fails. Successful cleanup then reconciles unreferenced photos. An untouched empty editor avoids an unnecessary ledger write.
- `CoastWild/UI/JournalController.swift:460–463`: Successful published-entry deletion now calls `cleanUnusedPhotos` after the core cascades linked drafts. Revision-only photos are removed while files still referenced by other ledger entries are retained.

No code was changed by this reviewer and no tests were rerun. Root reports Swift parse passed, 23 core tests passed, and the final UI regression suite is running.

## Original findings verified fixed

| Finding | Current evidence | Result |
| --- | --- | --- |
| P1 published entry overwritten by autosave | `JournalEditorController.init` creates/resumes a separate UUID draft with `sourceEntryID`; `CoastStore.saveEntry` atomically replaces the published source only on final Save | Fixed |
| Existing empty draft retains old text on Keep | `persistDraft` now saves empty draft payloads; no early content guard | Fixed, including the immediate new-entry Cancel path |
| Ordinary import/remove/discard photo leaks | Save, Keep draft and Discard call `cleanUnusedPhotos` only after successful ledger mutation | Fixed, including cascade deletion |
| Search controls disagree after Clear filters | `ExploreController` owns search/category controls and resets both with query/category/duration | Fixed |
| Trip edit overwrites destination timezone | Timezone initialized only for a newly created trip | Fixed |
| Failed export leaves temporary copy | Export owns folder outside do/catch and removes it in catch and share completion | Fixed |

## Contract follow-up

- Clear now resets onboarding and signs out to the first-use root after clearing current-account data. Other accounts are explicitly preserved by the confirmation.
- Change day now preserves the trip-item ID, snapshot and time, and uses the store's duplicate/day checks. Long trips use bounded input rather than an enormous action sheet.
- ON01 now opens shared Preferences for language and region; interests persist, so rebuilding the root after changing language retains onboarding choices.
- Progress now records sticky `completedAt` and preserves last viewed step.
- Minor mapping deviation: TR03 More still offers Complete/Reopen and Delete, while Edit is available as a separate navigation-bar action, rather than in More as the contract requests.
- Trips represent sort order by item array order, and trip membership by nesting, rather than explicit `sortOrder`/`tripId` fields; visible behavior is implemented. Catalog keys remain stable content identifiers. These are model mappings rather than current user-facing data-loss findings.
- Regions intentionally share labeled sample content; no verified destination catalog or production email backend is claimed.

## Verification boundary

This follow-up confirms code paths, not simulated failure injection or final runtime outcomes. Root should record the final UI regression result separately. The two targeted fixes were checked against their control flow and store semantics. Final UI test results should remain separately reported rather than inferred from this static review.
