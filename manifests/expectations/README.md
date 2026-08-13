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
`arithmetic/adder.v` at ~244s).

**Implemented** (`run_external_regression.py`'s `--probe-timeout`, default
60s): a file with a known-`TIMEOUT` baseline runs with that short probe
instead of the full 300s - just enough to confirm "still stuck" without
re-proving it from scratch every night. Everything else (no baseline, or a
`PASS`/`CLEAN_REJECT` baseline) always gets the full timeout. If a
known-`TIMEOUT` file completes within the probe, that is an **improvement**
(reported, doesn't fail the nightly) - the general improvement policy above
covers this, the probe timeout just makes checking for it cheap. Confirmed
working on the first real `workflow_dispatch` run: all 13 files with a
`TIMEOUT` baseline correctly used the 60s probe and matched.

### Lesson from the first real run: calibrate against CI, not your laptop

`c7552.v` was briefly promoted to a `PASS` baseline (266.4s) from an
isolated *local* run. On the actual GitHub Actions runner (run
`31739473048`) it exceeded 300s and failed the job as a false regression -
reverted back to `TIMEOUT`. The asymmetry matters: a `TIMEOUT` baseline that
occasionally finishes early is a harmless improvement; a `PASS` baseline
that occasionally overshoots is a job-failing false regression on every
slow run. For any file within shouting distance of the timeout ceiling
(currently only `c7552.v`, ~266-300s), don't promote it to `PASS` from a
single local measurement - wait for a stable pattern of passing CI runs
first, since CI runner performance doesn't necessarily match local hardware.
