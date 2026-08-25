# Adding a tool, simulator or validator

All three are manifest changes. The pipeline engine has no knowledge of any
individual tool, simulator or validator, and adding one should not require it to
grow any. Read [concepts.md](concepts.md) for the operation model and the
placeholder list.

- [A transformation tool](#a-transformation-tool)
- [A simulator](#a-simulator)
- [A validator](#a-validator)
- [A whole new HIF repository](#a-whole-new-hif-repository)
- [Worked example: a future C++ flow](#worked-example-a-future-c-flow)

## A transformation tool

`manifests/tools.yaml`:

```yaml
mytool:
  repository: hif-something
  consumes: hif
  produces: hif
  command: ["mytool", "{input}", "-o", "{workdir}/{name}.out.hif.xml"]
  artifact: "{workdir}/{name}.out.hif.xml"
```

`command[0]` is a binary *name*, resolved via `--bin-dir` then `PATH` — never a
path. `artifact` may contain a glob when the tool's naming is not fully
predictable. It must match at least one file; when it matches several they are
all the artifact, and every one of them has to be non-empty. That is not a
loophole — hif2verilog writes one `.v` per HIF DesignUnit, so a design whose
hierarchy reached the emitter is spread across several files and taking one
would drop the rest while still reparsing cleanly.

Declaring `{input}` means your tool takes exactly one file, and the runner
refuses to hand it a multi-file artifact rather than choosing for you. Use
`{inputs}` if it accepts a list.

Then reference it from a pipeline. No code changes.

## A simulator

`manifests/simulators.yaml`. The `compile`/`run` split is what gives
compile-once/run-many — one elaboration, N executions:

```yaml
mysim:
  language: verilog
  compile:
    command: ["mysim", "{options}", "{defines}", "-o", "{workdir}/sim.out", "-top", "{top}", "{sources}"]
    artifact: "{workdir}/sim.out"
    options: ["--some-flag"]
    define_template: "-D{value}"
  run:
    command: ["mysim-run", "{compiled}", "{params}", "--trace={trace}"]
    artifact: "{rundir}/trace.csv"
    param_template: "--{key}={value}"
  timeout_s: 60
```

Omit `compile` entirely for a simulator that interprets sources directly.

This repo never installs, builds, vendors or version-pins a simulator —
provisioning belongs to the environment. Nothing in the registry should depend
on a particular version.

Code is needed only if the invocation *model* is new: something that is neither
"compile once" nor "run N times".

## A validator

If an existing comparator fits, it is one line in `manifests/validators.yaml`:

```yaml
my_check:
  impl: artifact_equal
```

Available `impl`s: `artifact_equal`, `artifact_differs`,
`artifact_equals_fixture`.

For genuinely new comparison logic, add a function to `scripts/validators.py`
returning `(ok: bool, mismatch: str | None)`, register it in `IMPLS`, and add
its name to `manifest_schema.KNOWN_IMPLS` so a manifest typo is caught early
rather than at run time.

## A whole new HIF repository

1. Add it to `manifests/repositories.yaml` (URL, `depends_on`,
   `cmake_args_template`). Build order is derived from `depends_on` by
   topological sort, and its CTest run comes from the same file — no workflow
   change for either.
2. Add its ref to both `manifests/stable.yaml` and `manifests/develop.yaml`.
3. If it is relevant to the curated corpus, add its executables to
   `manifests/tools.yaml` and reference them from a pipeline — rather than
   inventing a parallel corpus or touching runner code.

## Worked example: a future C++ flow

Illustrative only; nothing below is wired up. It shows that
`Verilog -> frontend -> DDT -> A2Tool -> C++ backend -> run C++ -> compare
against RTL simulation` needs manifest entries, not engine changes.

```yaml
# tools.yaml
ddt:     {repository: hif-ddt,     consumes: hif, produces: hif, command: [...], artifact: "..."}
a2tool:  {repository: hif-a2tool,  consumes: hif, produces: hif, command: [...], artifact: "..."}
hif2cpp: {repository: hif-backend, consumes: hif, produces: cpp, command: [...], artifact: "..."}

# simulators.yaml - a compiled binary is the same compile-once/run-many shape
cxx_binary:
  language: cpp
  compile:
    command: ["g++", "{options}", "-o", "{workdir}/model", "{sources}"]
    artifact: "{workdir}/model"
    options: ["-O2", "-std=c++17"]
  run:
    command: ["{compiled}", "{params}", "--trace={trace}"]
    artifact: "{rundir}/trace.csv"
    param_template: "--{key}={value}"

# pipelines.yaml
rtl_vs_cpp:
  operations:
    - {id: frontend, kind: tool, use: verilog2hif}
    - {id: ddt,      kind: tool, use: ddt}
    - {id: a2tool,   kind: tool, use: a2tool}
    - {id: cpp,      kind: tool, use: hif2cpp}
    - id: sim_rtl
      kind: simulation
      use: iverilog
      sources: [{design: sources}, {fixture: testbench}]
      runs: [{id: reference}]
    - id: sim_cpp
      kind: simulation
      use: cxx_binary
      sources: [{from: cpp}, {fixture: harness}]
      runs: [{id: reference}]
    - id: equivalent
      kind: validation
      cases:
        - id: rtl_matches_cpp
          use: trace_equal
          left:  {from: sim_rtl, run: reference}
          right: {from: sim_cpp, run: reference}
```

`trace_equal` compares an RTL trace against a C++ trace unchanged — it only ever
knew how to compare two artifacts.
