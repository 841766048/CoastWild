# Native coins final review

Branch: `codex/native-coin-learning`.

## Scope

Reviewed local wallet invariants, atomic persistence and duplicate fulfillment; purchase/restore/transaction-update integration; existing JS bridge product mapping; explicit guide spending and ownership; native purchase state recovery.

## Findings resolved

1. A persisted credit followed by interruption before StoreKit finish could stay confirming after recovery. The model now remembers pending transaction identities and checks their durable ledger entries, including entries created before restart.
2. Terminal inactive verification cleared the coordinator queue but left the UI confirming. Retry now reconciles pending state and presents a terminal failure when there is no credit.

Two regression UI tests failed before the fix at their intended assertions. Targeted re-review found both issues addressed and no further actionable issue in those changes. Final test results are recorded in the UI report.

## Boundaries

The wallet is intentionally local and device-wide for this installation. Real Apple sandbox payment and live backend fulfillment were not exercised. The server must accept product `1coins_19` and the configured native purchase source before release. Consumable balance is not restored after deleting app data, and no server-side spending or refund reconciliation is provided.
