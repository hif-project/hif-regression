# HIF Regression

Cross-repository integration and regression testing for the HIF toolchain.

This is **test/integration infrastructure only** - not a HIF library, and not
a runtime dependency of any HIF tool. Nothing here is meant to be linked
against or imported by `hif-core`, `hif-frontend`, `hif-backend`,
`hif-muffin`, or any future HIF-based tool.

```
                     hif-regression
                          |
          +---------------+----------------+
          |               |                |
      hif-frontend    hif-backend      hif-muffin
          \               |                /
           +----------- hif-core ----------+
```

It currently validates:

- [hif-core](https://github.com/hif-project/hif-core) - shared AST/IR library
- [hif-frontend](https://github.com/hif-project/hif-frontend) - Verilog/VHDL -> HIF
- [hif-backend](https://github.com/hif-project/hif-backend) - HIF -> Verilog/VHDL(/SystemC)
- [hif-muffin](https://github.com/hif-project/hif-muffin) - RTL fault injection, built on the above

Each of those repos owns its own unit/product tests and CI. This repo does
not duplicate those - it validates the four repos **together**: does the
toolchain still build end-to-end, and does it still produce correct output
across a curated HDL corpus and pinned external benchmark suites.

**Supported platform: Linux only.**

## Stable vs. develop

Two separate questions, two separate manifests under `manifests/`:

- `manifests/stable.yaml` - the coordinated, released toolchain baseline
  (currently `v1.0.0` for all four repos). "Does the published toolchain
  still reproduce successfully?" Run manually, or on a slower schedule.
- `manifests/develop.yaml` - floating development integration (all four repos
  at `develop` HEAD). "Do today's development branches still integrate
  together?" This is what the nightly runs by default.

Both are keyed identically to `manifests/repositories.yaml` (below).

## Running locally

```sh
scripts/build_toolchain.py --manifest develop --build-type Release --parallel 2
```

`manifests/repositories.yaml` owns the build graph - what to clone, and in
what order (a topological sort of its `depends_on`, not a hardcoded list).
The script clones every repo fresh into `.workspace/` (gitignored - never
reuses or relies on any pre-existing sibling checkout on your machine),
builds them in that order (`hif-core` first; the rest discover it via
`-DHIF_DIR=.workspace/install`, the shared install prefix - see each
repo's `cmake_args_template` in `repositories.yaml`), and writes
`.workspace/toolchain.env` with the resolved paths for later steps. Build
parallelism is capped at `--parallel 2` by default - unbounded parallelism
has previously exhausted memory on GitHub-hosted runners while compiling
`hif-core`.

`--build-type` defaults to `Release`. hif-regression measures integration and
corpus behavior, not development ergonomics, and a known slow tree-
simplification pass only shows up in Debug builds; pass `--build-type Debug`
for manual investigation of a specific failure instead.

Each repo's own CTest suite still runs against its own build directory, e.g.:

```sh
source .workspace/toolchain.env
ctest --test-dir "$WORKSPACE/hif-backend/build" --output-on-failure
```

The curated corpus runs through `scripts/run_regression.py`; external
benchmarks run through `scripts/run_external_regression.py` (see below) -
both write their own JSON report under `reports/` (gitignored):

```sh
export PATH="$PREFIX/bin:$PATH"
export LD_LIBRARY_PATH="$PREFIX/lib:${LD_LIBRARY_PATH:-}"
python3 scripts/run_regression.py --manifest-label develop
```

It prints a human-readable summary (per-category PASS/CLEAN_REJECT/CRASH/
TIMEOUT counts, plus a list of any design that didn't cleanly PASS every
stage) and writes the full machine-readable detail to
`reports/curated-report.json`. `scripts/report.py` renders both reports as
one Markdown summary (what the nightly publishes to the GitHub Actions job
summary):

```sh
python3 scripts/report.py   # reads reports/curated-report.json + reports/external-report.json
```

## Curated design corpus

`designs/<category>/` holds small, hand-written HDL fixtures we own and
understand completely - not a benchmark dump. Categories: `combinational`,
`sequential`, `parameterized`, `hierarchical`, `structural`. Point is
controlled semantic coverage, not quantity.

Each design is a plain source file (`designs/<category>/<name>.v`, or a
folder for genuinely multi-file designs), run through a named **pipeline**
- an ordered tool chain defined in `manifests/pipelines.yaml`, built from the
tool registry in `manifests/tools.yaml`. Every category has a default
pipeline (`suite_defaults` in `pipelines.yaml`, currently `plain_roundtrip`
- frontend parse, HIF regeneration, backend regen, regenerated-HDL reparse -
everywhere) and expects a clean `PASS` at each step - for our own corpus,
regression means failure. A design only needs an optional `<name>.json`
sidecar when it deviates from its category's default, e.g. `and2.json`
selects `"pipeline": "muffin_roundtrip"` to also probe Muffin instrumentation.

**To add a new curated design:** drop the source file in the right category,
add a `.json` sidecar only if the default pipeline doesn't fit, and run
`scripts/run_regression.py --only <name>` to check it before committing.
**To add a new tool** (a future `ddt`, another backend, ...): add it to
`tools.yaml` (command + artifact templates - see that file's header
comment) and reference it from a pipeline in `pipelines.yaml`. No runner
code changes - `run_regression.py`/`pipeline_engine.py` have no tool-specific
knowledge.

## External benchmarks

`manifests/external-benchmarks.yml` pins each external suite by exact
repository + commit SHA + sub-path - never a floating branch. Suites are
fetched into `external/.cache/` (gitignored) at runtime; nothing is vendored
into git. Bumping a pinned `ref` is a deliberate, reviewable commit.

```sh
pip install pyyaml  # only extra Python dependency, used to parse the manifest
python3 scripts/run_external_regression.py
```

Only the frontend layer (`verilog2hif`) is exercised for external files today
- matching the scope of the prior informal investigation this pins itself
against. Results are classified per file as `PASS`, `CLEAN_REJECT`, `CRASH`, or
`TIMEOUT`. `manifests/expectations/` holds the checked-in baseline once one
exists for a suite (see that directory's README for the exact regression /
improvement policy) - the primary rule is **zero unexpected crashes**. A file
with a known-`TIMEOUT` baseline runs with a much shorter `--probe-timeout`
(60s by default) instead of the full `--timeout` (300s) - enough to confirm
"still stuck" without spending the full budget every night; if one completes
within that window, it is reported as an improvement, not a regression.

Current suites: `logikbench` (`basic`, `iscas85`) and `epfl` /
`lsils/benchmarks` (`arithmetic`, `random_control`). See
`manifests/external-benchmarks.yml` for exact pins and per-suite license
notes - these corpora are not uniformly licensed, don't assume otherwise.

## Adding a future HIF tool to the integration graph

1. Add it to `manifests/repositories.yaml` (repository URL, `depends_on`,
   `cmake_args_template`) - build order is derived automatically, and so is
   its CTest run (`scripts/run_ctest_suites.py` reads the same file) - no
   workflow change needed for either.
2. Add its ref to both `manifests/stable.yaml` and `manifests/develop.yaml`.
3. If it's relevant to the curated corpus, add its executable(s) to
   `manifests/tools.yaml` and reference them from a pipeline in
   `manifests/pipelines.yaml` (a new named pipeline, or a probe on an
   existing one) rather than inventing a parallel corpus or touching
   runner code.

## What the nightly checks

`.github/workflows/nightly.yml` (schedule + manual `workflow_dispatch`)
builds the floating-`develop` manifest from scratch, runs each repo's own
CTest suite, runs the curated corpus, runs the pinned external benchmarks,
and publishes a summary to the GitHub Actions job summary plus a detailed
JSON artifact. It fails on an actual regression (a crash, or a
worse-than-baseline classification) - a known, already-documented clean
rejection or a pre-existing, explicitly-reviewed crash/timeout does not fail
the job by itself, but always stays visible in the report.

## Non-goals

This repo does not fix HIF bugs, extend Verilog/SystemVerilog support, vendor
full external benchmark suites, or become a build/runtime dependency of any
HIF tool. When regression work finds a real toolchain bug, it gets
reproduced, classified, and documented here - not silently patched.
