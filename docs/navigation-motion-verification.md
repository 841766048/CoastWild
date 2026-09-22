# Navigation Motion Verification

Verified on 2026-09-21 with Xcode's iOS 18.6 `CoastWild QA` simulator.

## Implemented behavior

- Push: 0.28s right-to-left transition with restrained 22% outgoing parallax.
- Pop: 0.24s reverse transition.
- Edge back: interactive progress, short slow-drag cancellation, and fast/long-drag completion.
- Tab: 0.18s fade with a 6pt vertical settle and interruption-safe cleanup.
- Dialog: 0.22s open from 0.96 scale and 0.16s close to 0.98 scale.
- Reduce Motion: hierarchy and Tab spatial motion disabled; custom dialogs use a fade capped at 0.12s.

## Automated evidence

- Motion-contract red gate: `/tmp/coast-motion-core-red.log`.
- Motion-contract green gate: `/tmp/coast-motion-core-green.log`.
- Core regression: `swift test` passed 57 tests with 0 failures.
- Focused interaction regression: `/tmp/coast-motion-ui-cancel-slow.log` passed rapid Tab switching, Push, cancelled edge Pop, completed edge Pop, repeat Push, dialog open, and dialog close.
- Full UI regression: `/tmp/coast-motion-full-test-final.log` passed 5 tests with 0 failures, including the corrected slow cancellation gesture.
- `git diff --check` passed.

## Remaining device check

The automated interaction checks ran in Simulator. Before release, confirm edge-back feel and Reduce Motion behavior once on a physical iPhone because touch velocity and refresh rate can differ from Simulator.
