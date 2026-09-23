# Native coin recovery review

## Regression coverage

- `NativeCoinRecoveryUITests.testAlreadyCreditedUnfinishedPurchaseRecoversWithoutDuplicateCredit`: a DEBUG store delays finish after real wallet fulfillment; the test confirms 100 coins, terminates, relaunches with the same unfinished transaction, and expects successful recovery with exactly one credit.
- `NativeCoinRecoveryUITests.testTerminalRejectionExitsConfirmationAndAllowsNextPurchase`: verification first fails transiently, then returns inactive; the UI must show a terminal failure and permit a new successful purchase with only one total credit.

Fixtures remain within the existing DEBUG-only native coin test store/server, activated through the existing UI-test environment. Production wallet writes and coordinator fulfillment are exercised without fake ledger insertion.

## Validation

- Tests and fixtures written before the production fix.
- Parent simulator RED run confirmed both regressions failed at the intended success/terminal alert assertions: `build/native-coins-recovery-red.xcresult` (53 seconds).
- `git diff --check` passes.
- Simulator red/green runs are coordinated by the parent task to avoid concurrent Xcode builds.
- Initial green run passed credited/unfinished recovery. The terminal-failure test used an incorrect `app.alerts` selector for the application's custom `CoastDialog`; corrected it to the existing suite's `staticTexts`/`buttons` pattern. Final rerun pending.

## Fix

Final GREEN: both recovery tests passed (46.18 seconds,0 failures), `build/native-coins-recovery-green.xcresult`, `/tmp/coins-recovery-green.log`.

The model retains pending transaction identities, including synchronization results captured before product loading yields to the transaction observer. Once pending work clears, recovery checks the persisted `transaction:<id>` ledger entry, including credits written before a crash or observer completion. A cleared pending queue without a matching credit becomes a terminal failure. Retry errors re-read coordinator state so transient failures remain recoverable and inactive verification permits a later purchase.
