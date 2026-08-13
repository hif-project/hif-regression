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

- [hif-core](https://github.com/esd-univr/hif-core) - shared AST/IR library
- [hif-frontend](https://github.com/esd-univr/hif-frontend) - Verilog/VHDL -> HIF
- [hif-backend](https://github.com/esd-univr/hif-backend) - HIF -> Verilog/VHDL(/SystemC)
- [hif-muffin](https://github.com/esd-univr/hif-muffin) - RTL fault injection, built on the above

Each of those repos owns its own unit/product tests and CI. This repo does
not duplicate those - it validates the four repos **together**: does the
toolchain still build end-to-end, and does it still produce correct output
across a curated HDL corpus and pinned external benchmark suites.

**Supported platform: Linux only.**

## Stable vs. develop

Two separate questions, two separate manifests under `manifests/`:

- `manifests/stable.env` - the coordinated, released toolchain baseline
  (currently `v1.0.0` for all four repos). "Does the published toolchain
  still reproduce successfully?" Run manually, or on a slower schedule.
- `manifests/develop.env` - floating development integration (all four repos
  at `develop` HEAD). "Do today's development branches still integrate
  together?" This is what the nightly runs by default.

## Running locally

```sh
scripts/build_toolchain.sh --manifest develop --build-type Release --parallel 2
```

This clones all four repos fresh into `.workspace/` (gitignored - never
reuses or relies on any pre-existing sibling checkout on your machine),
builds them in dependency order (`hif-core` first; `hif-frontend`,
`hif-backend`, `hif-muffin` each discover it via `-DHIF_DIR=.workspace/install`,
the shared install prefix), and writes `.workspace/toolchain.env` with the
resolved paths for later steps. Build parallelism is capped at
`--parallel 2` by default - unbounded parallelism has previously exhausted
memory on GitHub-hosted runners while compiling `hif-core`.

`--build-type` defaults to `Release`. hif-regression measures integration and
corpus behavior, not development ergonomics, and a known slow tree-
simplification pass only shows up in Debug builds; pass `--build-type Debug`
for manual investigation of a specific failure instead.

Each repo's own CTest suite still runs against its own build directory, e.g.:

```sh
source .workspace/toolchain.env
ctest --test-dir "$WORKSPACE/hif-backend/build" --output-on-failure
```

The curated corpus runs through `scripts/run_regression.py` (external
benchmarks join it in the same way once wired up), e.g.:

```sh
export PATH="$PREFIX/bin:$PATH"
export LD_LIBRARY_PATH="$PREFIX/lib:${LD_LIBRARY_PATH:-}"
python3 scripts/run_regression.py --manifest-label develop
```

It prints a human-readable summary (per-category PASS/CLEAN_REJECT/CRASH/
TIMEOUT counts, plus a list of any design that didn't cleanly PASS every
layer) and writes the full machine-readable detail to
`reports/curated-report.json` (gitignored). A standalone `scripts/report.py`
for combining multiple corpora into one CI job summary will show up once the
nightly workflow actually needs it - not before.

## Curated design corpus

`designs/<category>/` holds small, hand-written HDL fixtures we own and
understand completely - not a benchmark dump. Categories: `combinational`,
`sequential`, `parameterized`, `hierarchical`, `structural`. Point is
controlled semantic coverage, not quantity.

Each design is a plain source file (`designs/<category>/<name>.v`, or a
folder for genuinely multi-file designs). By default the runner exercises
every layer (frontend parse, HIF regeneration, backend regen, regenerated-HDL
re-parse) and expects a clean `PASS` at each - for our own corpus, regression
means failure. A design only needs an optional `<name>.json` sidecar next to
it when it deviates from that default (e.g. opting into Muffin
instrumentation, or restricting which layers apply).

**To add a new curated design:** drop the source file in the right category,
add a `.json` sidecar only if the defaults don't fit, and run
`scripts/run_regression.py --only <name>` to check it before committing.

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
improvement policy) - the primary rule is **zero unexpected crashes**.

Current suites: `logikbench` (`basic`, `iscas85`) and `epfl` /
`lsils/benchmarks` (`arithmetic`, `random_control`). See
`manifests/external-benchmarks.yml` for exact pins and per-suite license
notes - these corpora are not uniformly licensed, don't assume otherwise.

## Adding a future HIF tool to the integration graph

1. Add its ref to both `manifests/stable.env` and `manifests/develop.env`.
2. Add a build step to `scripts/build_toolchain.sh` after its dependencies,
   installing into the same shared prefix.
3. If it has its own CTest suite, add a step to run it in
   `.github/workflows/nightly.yml`.
4. If it's relevant to the curated corpus (e.g. it consumes HIF like
   hif-muffin does), extend the relevant designs' sidecar metadata rather
   than inventing a parallel corpus.

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
