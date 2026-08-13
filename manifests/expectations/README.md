# Expectations (external-corpus baselines)

Per-file expected classification, keyed by file path within a suite (path
relative to the suite's repository root - the same "file" value the runner
puts in its JSON report). Structured per-stage from the start
(`stages.frontend.status`) even though only the frontend stage is exercised
today, so adding a `backend`/`reparse` stage later is additive, not a
breaking format change. `reference_elapsed_s` on a `PASS` entry is
informational only (from the run that established the baseline) - it is
never compared against, only read by humans deciding timeout policy.

`logikbench.json` and `epfl.json` were established 2026-08-13 from an
isolated, non-concurrent run at a 300-second timeout ceiling, on top of:

- `logikbench/basic` restricted to `<circuit>/rtl/*.v` only - the
  `testbench/test_*_smoke.v` files in the same repo are simulation
  harnesses, not RTL, and are not part of this suite's file set at all (see
  `manifests/external-benchmarks.yml`'s `file_glob`).
- `icg` and `latch` excluded from `logikbench/basic` entirely (see that
  manifest's `exclude` list) - both instantiate a library cell
  (`la_clkicgand`, `la_vlatq` respectively) not present in this suite path.
  Not self-contained, not a HIF parser crash, not classified here at all.

## Regression / improvement policy

- A file regressing from a better bucket to a worse one (e.g. `PASS` ->
  `CRASH`, `PASS` -> `CLEAN_REJECT`, `CLEAN_REJECT`/`TIMEOUT` -> `CRASH`) is a
  regression and fails the nightly.
- A file improving (e.g. `CRASH` -> `PASS`, `CLEAN_REJECT` -> `PASS`,
  `TIMEOUT` -> `PASS`) does not fail the nightly - review and update the
  baseline to reflect the improvement (not automatic).
- A brand new `CRASH` on a file with no prior baseline entry always fails the
  nightly, unconditionally.
- Known, explicitly-reviewed pre-existing `CRASH`/`TIMEOUT` entries may be
  carried in the baseline without failing the nightly, but they always stay
  visible in the generated report - "tolerated" is not "hidden".

## Timeout policy: calibration ceiling vs. nightly operational timeout

300 seconds is the ceiling used to *establish* this baseline (to tell
"genuinely slow" apart from "shows no evidence of ever finishing" - see the
per-file `reference_elapsed_s` values above; the worst genuine finisher was
`arithmetic/adder.v` at ~244s). It is not, by itself, meant to be what the
nightly spends per file forever - today the runner still uses one timeout
for every file, which means it currently *does* wait the full 300s on each
known-`TIMEOUT` file. That is correct but wasteful: ~70 of the ~79 minutes
the external suites currently cost is spent re-confirming 14 files we
already know don't finish.

Intended future policy (not yet implemented - tracked for the pipeline
refactor, not built ad hoc into today's runner):

- Files with no baseline, or a `PASS` baseline, run with the full regression
  timeout (300s today).
- Files with a known `TIMEOUT` baseline run with a much shorter probe
  timeout instead (~30-60s) - just enough to confirm "still stuck", not to
  re-prove it from scratch every night.
- If a known-`TIMEOUT` file completes within that shorter probe, that is an
  **improvement** (report it, don't fail the nightly), not a regression -
  the general improvement policy above already covers this, the probe
  timeout is just what makes checking for it cheap.
