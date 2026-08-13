# Expectations (external-corpus baselines)

Per-file expected classification (`PASS` / `CLEAN_REJECT` / `CRASH` /
`TIMEOUT`) for each pinned external suite, keyed by file path within that
suite.

This directory is intentionally empty until the first full external-corpus
run has been executed and reviewed. Baselines are derived from an actual
observed run, not seeded from prior informal investigation notes - see the
hif-muffin `docs/known-issues.md` history for context on what to expect, but
that history is not copied in here as truth.

Policy once a baseline exists for a suite:

- A file regressing from a better bucket to a worse one (e.g. `PASS` ->
  `CRASH`, `PASS` -> `CLEAN_REJECT`, `CLEAN_REJECT`/`TIMEOUT` -> `CRASH`) is a
  regression and fails the nightly.
- A file improving (e.g. `CRASH` -> `PASS`, `CLEAN_REJECT` -> `PASS`,
  `TIMEOUT` -> `PASS`) does not fail the nightly - update the baseline to
  reflect the improvement.
- A brand new `CRASH` on a file with no prior baseline entry always fails the
  nightly, unconditionally.
- Known, explicitly-reviewed pre-existing `CRASH`/`TIMEOUT` entries may be
  carried in the baseline without failing the nightly, but they always stay
  visible in the generated report - "tolerated" is not "hidden".
