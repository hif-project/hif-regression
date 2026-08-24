# Running hif-regression

Linux only.

- [Build a toolchain](#build-a-toolchain)
- [Run the curated corpus](#run-the-curated-corpus)
- [Run one design against binaries you already have](#run-one-design-against-binaries-you-already-have)
- [Run each repo's own unit tests](#run-each-repos-own-unit-tests)
- [Run the external benchmarks](#run-the-external-benchmarks)
- [Reading the result](#reading-the-result)

## Build a toolchain

```sh
scripts/build_toolchain.py --manifest develop --build-type Release --parallel 2
```

This clones every repository **fresh** into `.workspace/` — it never reuses or
relies on a sibling checkout you happen to have — builds them in dependency
order, and writes `.workspace/toolchain.env` with the resolved paths.

- `--manifest develop` floats all repos at `develop` HEAD: "do today's branches
  still integrate?" This is what the nightly uses.
- `--manifest stable` pins the released baseline: "does the published toolchain
  still reproduce?"
- `--parallel` defaults to 2. Unbounded parallelism has exhausted memory on
  GitHub-hosted runners while compiling `hif-core`.
- `--build-type` defaults to `Release`. Use `Debug` only to investigate a
  specific failure — a known slow tree-simplification pass shows up there.

## Run the curated corpus

```sh
source .workspace/toolchain.env
export PATH="$PREFIX/bin:$PATH"
export LD_LIBRARY_PATH="$PREFIX/lib:${LD_LIBRARY_PATH:-}"
python3 scripts/run_regression.py --manifest-label develop
```

Prints a per-category summary and writes `reports/curated-report.json`.

Behavioral pipelines need `iverilog` and `vvp` on `PATH`. This repo never
installs, builds or version-pins a simulator — provisioning belongs to the
environment.

## Run one design against binaries you already have

The fast loop while writing a design. Skip `build_toolchain.py` entirely and
point `--bin-dir` at whatever binaries you want to test:

```sh
mkdir -p /tmp/hifbin && cd /tmp/hifbin
ln -sf ~/repositories/hif/hif-frontend/build/verilog2hif .
ln -sf ~/repositories/hif/hif-frontend/build/vhdl2hif .
ln -sf ~/repositories/hif/hif-backend/build/hif2verilog .
ln -sf ~/repositories/hif/hif-backend/build/hif2vhdl .

cd ~/repositories/hif/hif-regression
python3 scripts/run_regression.py --only my_design --bin-dir /tmp/hifbin
```

`--only` matches a substring of the design name. `--bin-dir` is searched before
`PATH`, so this tests exactly the build you just made — which is also how you
check that a design fails against a *reverted* fix, the only way to know it
discriminates.

Useful companions: `--work-dir` to keep intermediate artifacts somewhere you can
inspect, `--timeout` for a slow stage, `--report` to write the JSON elsewhere.

## Run each repo's own unit tests

Each repository owns its own CTest suite; this repo does not duplicate them.

```sh
source .workspace/toolchain.env
ctest --test-dir "$WORKSPACE/hif-backend/build" --output-on-failure
```

`scripts/run_ctest_suites.py` runs all of them, driven by the same
`manifests/repositories.yaml` that drives the build order.

## Run the external benchmarks

```sh
pip install pyyaml
python3 scripts/run_external_regression.py
```

Suites are pinned by repository + commit SHA + sub-path in
`manifests/external-benchmarks.yml`, fetched into `external/.cache/` at runtime,
never vendored. Only the frontend layer is exercised. Baselines live in
`manifests/expectations/`; the primary rule is **zero unexpected crashes**.

## Reading the result

Per-stage classification:

| status | meaning |
|---|---|
| `PASS` | exited 0 and produced the expected artifact |
| `CLEAN_REJECT` | exited nonzero, not by signal, with a known "deliberately unsupported" message |
| `FAIL` | a validation verdict — produced by validators only |
| `CRASH` | killed by a signal, or exited nonzero without matching a known rejection |
| `TIMEOUT` | exceeded the per-stage timeout |

An unrecognized failure is conservatively `CRASH`, never bucketed away quietly.
Signal-vs-exit-code is the primary discriminator because HIF's own deliberate
rejection path (`messageError`, `messageAssert`) always calls `exit()` and never
raises a signal.

Two further design-level verdicts come from a design's `expected_failure`
declaration — `XFAIL` (failed as documented; not a regression) and `XPASS`
(declared a failure and passed; remove the key). See
[adding-a-design.md](adding-a-design.md#designs-that-are-expected-to-fail).

**For the curated corpus, a failure is a real failure.** These are fixtures the
project owns and understands; there is no baseline to drift against. The one
exception is a declared `expected_failure`.

Render both reports as one Markdown summary — what the nightly publishes:

```sh
python3 scripts/report.py
```
