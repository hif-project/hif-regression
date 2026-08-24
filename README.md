# hif-regression

Cross-repository integration and regression testing for the HIF toolchain.

## What this is

Each HIF repository owns its own unit tests and CI. This repo does not duplicate
them — it validates them **together**: does the toolchain still build end to
end, and does it still produce correct output across a curated HDL corpus and
pinned external benchmark suites?

```
                     hif-regression
                          |
          +---------------+----------------+
          |               |                |
      hif-frontend    hif-backend      hif-muffin
          \               |                /
           +----------- hif-core ----------+
```

## What this is not

**Test and integration infrastructure only.** Not a HIF library, and not a
runtime dependency of anything. Nothing here is meant to be linked against or
imported by `hif-core`, `hif-frontend`, `hif-backend`, `hif-muffin`, or any
future HIF tool.

It also does not fix HIF bugs, extend HDL support, or vendor external benchmark
suites. When regression work finds a real toolchain bug, it gets reproduced,
classified and documented here — and filed against the repository that owns it,
not silently patched.

**Supported platform: Linux only.**

## I want to...

| | read |
|---|---|
| add a design to the corpus | [docs/adding-a-design.md](docs/adding-a-design.md) |
| give a design stimulus and a behavioral check | [docs/adding-a-design.md](docs/adding-a-design.md) |
| leave a design failing because it found a bug | [docs/adding-a-design.md](docs/adding-a-design.md#designs-that-are-expected-to-fail) |
| add a tool, simulator or validator | [docs/adding-a-tool.md](docs/adding-a-tool.md) |
| add a whole new HIF repository | [docs/adding-a-tool.md](docs/adding-a-tool.md#a-whole-new-hif-repository) |
| add or change a pipeline | [docs/adding-a-pipeline.md](docs/adding-a-pipeline.md) |
| build a toolchain and run any of this | [docs/running.md](docs/running.md) |
| check one design without a full rebuild | [docs/running.md](docs/running.md#run-one-design-against-binaries-you-already-have) |
| understand how the runner works | [docs/concepts.md](docs/concepts.md) |

## Repository structure

```
designs/          curated HDL corpus, by category:
                    combinational/ sequential/ parameterized/
                    hierarchical/ structural/
                  A design is a source file, or a directory when it is
                  multi-file or carries a testbench and oracles.

manifests/        everything the runner knows, as data:
  repositories.yaml     the build graph - what to clone, and depends_on
  stable.yaml           released baseline refs
  develop.yaml          floating develop refs
  tools.yaml            transformation tools
  simulators.yaml       simulators
  validators.yaml       comparators
  pipelines.yaml        named operation chains + per-category defaults
  external-benchmarks.yml   external suites, pinned by commit SHA
  expectations/         checked-in baselines for external suites

scripts/          the runner. No tool-, simulator- or validator-specific
                  knowledge lives here; adding one is a manifest change.
  build_toolchain.py        clone + build, in dependency order
  run_regression.py         the curated corpus
  run_external_regression.py  the pinned external suites
  run_ctest_suites.py       each repo's own unit tests
  report.py                 renders both reports as Markdown

docs/             the guides linked above
external/         external suites fetched at runtime (gitignored)
reports/          generated reports (gitignored)
```

## Two questions, two manifests

- `manifests/develop.yaml` — all repos at `develop` HEAD. *Do today's
  development branches still integrate?* This is what the nightly runs.
- `manifests/stable.yaml` — the coordinated released baseline. *Does the
  published toolchain still reproduce?* Run manually, or on a slower schedule.

Both are keyed identically to `manifests/repositories.yaml`.

## The nightly

`.github/workflows/nightly.yml` (schedule + manual `workflow_dispatch`) builds
the floating-`develop` manifest from scratch, runs each repo's CTest suite, the
curated corpus and the pinned external benchmarks, then publishes a summary to
the job summary plus a detailed JSON artifact.

It fails on a real regression: a crash, or a worse-than-baseline classification.
A documented clean rejection, a reviewed pre-existing external crash, or a
declared [expected failure](docs/adding-a-design.md#designs-that-are-expected-to-fail)
does not fail the job by itself — but all of them stay visible in the report.
