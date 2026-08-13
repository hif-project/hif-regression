# External benchmark corpora

This directory does **not** vendor any external benchmark suite. External
corpora (currently [zeroasiccorp/logikbench](https://github.com/zeroasiccorp/logikbench)
and [lsils/benchmarks](https://github.com/lsils/benchmarks), the EPFL
combinational suite) are referenced reproducibly by exact commit SHA in
[`manifests/external-benchmarks.yml`](../manifests/external-benchmarks.yml),
and fetched into `external/.cache/` (gitignored) at runtime by the regression
runner.

A deliberate update of a pinned `ref` in that manifest is a normal, reviewable
commit - the runner never follows a floating branch/HEAD for these.

Do not assume every file in an external corpus shares the repository's
top-level license. See the `notes`/`license` fields per suite in
`external-benchmarks.yml`, and the upstream LICENSE files under the fetched
path itself, before redistributing anything derived from these corpora.
