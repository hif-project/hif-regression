# Adding to hif-regression

Everything below is a manifest change unless it says otherwise. The pipeline
engine has no knowledge of any individual tool, simulator or validator, and
adding one should not require it to grow any.

- [Placeholders](#placeholders)
- [A new transformation tool](#a-new-transformation-tool)
- [A new simulator](#a-new-simulator)
- [A new validator](#a-new-validator)
- [A new pipeline](#a-new-pipeline)
- [A new curated design](#a-new-curated-design)
- [A new behavioral test](#a-new-behavioral-test)
- [Worked example: a future C++ flow](#worked-example-a-future-c-flow)

## The three operation kinds

A pipeline is an ordered list of operations. Each has an `id` (independent of
whatever implements it), a `kind`, and a `use` naming an entry in that kind's
registry.

| kind | registry | consumes | produces | asserts |
|---|---|---|---|---|
| `tool` | `manifests/tools.yaml` | artifacts | artifacts | nothing |
| `simulation` | `manifests/simulators.yaml` | sources + stimulus | traces | nothing |
| `validation` | `manifests/validators.yaml` | results | a verdict | yes |

These stay distinct on purpose. A simulation that also decided pass/fail would
hide *why* a behavioral test failed; a validator that also ran a simulator
could not be reused across simulators.

Operations execute strictly top to bottom, stopping at the first non-`PASS`.
There is no scheduler and no dependency resolution. An operation with no
explicit `inputs` consumes its predecessor's artifact; an explicit
`inputs: [<id>]` names an earlier operation.

## Placeholders

Fixed, and the only substitution that exists — this is argv construction, not a
scripting language.

**Scalar** — substituted inside a token:

| | meaning |
|---|---|
| `{input}` | first input path |
| `{workdir}` | this operation's working directory |
| `{name}` | the design's top-level name |
| `{top}` | simulation top (default `{name}_tb`) |
| `{compiled}` | artifact produced by the compile phase |
| `{rundir}` | this run's directory |
| `{trace}` | this run's result artifact |

**List** — must be the *entire* token, expands to zero or more argv entries:

`{inputs}` `{sources}` `{defines}` `{params}` `{options}`

A list placeholder inside a larger token is an error, not a silent
`str(list)`. An unknown placeholder is an error naming the operation and the
token.

## A new transformation tool

Add to `manifests/tools.yaml`:

```yaml
mytool:
  repository: hif-something
  consumes: hif
  produces: hif
  command: ["mytool", "{input}", "-o", "{workdir}/{name}.out.hif.xml"]
  artifact: "{workdir}/{name}.out.hif.xml"
```

`command[0]` is a binary name resolved via `--bin-dir` then `PATH`, never a
path. `artifact` may contain a glob when the tool's naming isn't fully
predictable; it must resolve to exactly one file.

Then reference it from a pipeline. No code changes.

## A new simulator

Add to `manifests/simulators.yaml`. The `compile`/`run` split is what gives
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
provisioning belongs to the environment (apt in CI, whatever is present
locally). Nothing in the registry should depend on a particular version.

Code is needed only if the invocation *model* is new (something that is neither
"compile once" nor "run N times").

## A new validator

If an existing comparator fits, it is one line in `manifests/validators.yaml`:

```yaml
my_check:
  impl: artifact_equal
```

Available `impl`s: `artifact_equal`, `artifact_differs`,
`artifact_equals_fixture`.

For genuinely new comparison logic, add a function to `scripts/validators.py`
returning `(ok: bool, mismatch: str | None)`, register it in `IMPLS`, and add
its name to `manifest_schema.KNOWN_IMPLS` so a typo in a manifest is caught
early rather than at run time.

## A new pipeline

Add an ordered `operations` list to `manifests/pipelines.yaml`, then either set
it as a category default under `suite_defaults` or select it per design with a
`"pipeline"` key in `design.json`.

## A new curated design

Drop the source in the right category under `designs/`. A single-file design
needs no sidecar — it inherits its category's default pipeline. Check it before
committing:

```sh
python3 scripts/run_regression.py --only <name>
```

Curated failures are real failures. If a new fixture fails, fix the fixture —
or, if the toolchain is genuinely at fault, open an issue on the repo that owns
it and use a construct that round-trips. Never weaken an expectation, and never
park a permanently-failing design here.

## A new behavioral test

Behavioral coverage is an orthogonal capability, not a category. A design gains
it by moving to directory form **inside its existing category** — never by
being duplicated under some `behavioral/` tree.

```
designs/combinational/and2/
  and2.v            RTL
  and2_tb.v         stimulus, shared by both compiles
  design.json       the DUT: top, pipeline, sources, fixtures
  behavior.yaml     runs (fault selection) + expectations (oracle)
  expect_*.csv      oracles
```

`design.json` must list `sources` explicitly, or the testbench will be picked
up as a design source:

```json
{
    "top": "and2",
    "pipeline": "muffin_behavioral",
    "sources": ["and2.v"],
    "fixtures": {"testbench": "and2_tb.v", "expect_sa0_y": "expect_sa0_y.csv"}
}
```

### The testbench

One testbench drives both the reference and the instrumented compile. The
activation port exists only in the instrumented netlist, so connect it
conditionally; the simulation operation supplies the define.

```verilog
dut u_dut (.a(a), .b(b), .y(y)
`ifdef MUFFIN_MUT
  , .muffinMutPort(mut)
`endif
);
```

Read the fault selection and the trace path from plusargs, so one compiled
binary serves every run, and size the path register generously — a truncated
path fails silently:

```verilog
reg [4095:0] tracefile;
if (!$value$plusargs("mut=%d", mut)) mut = 0;
if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
fd = $fopen(tracefile, "w");
if (fd == 0) begin $display("ERROR: cannot open trace file"); $finish; end
```

Write CSV with `$fdisplay`. Structured output beats parsing human-oriented
stdout.

### behavior.yaml

Three separate concerns; keep them separate. Stimulus lives in the testbench,
selection in `runs`, expectation in `expectations`.

```yaml
runs:
  - {id: golden, params: {mut: 0}}
  - id: sa0_y
    params:
      mut: {from: enumerate, array: faults, where: {signal: y, bit: 0, type: stuck-at-0}, take: id}

expectations:
  - id: golden_matches_rtl
    use: trace_equal
    left:  {from: simulate_reference,    run: reference}
    right: {from: simulate_instrumented, run: golden}
  - id: sa0_y_expected_trace
    use: expected_trace
    left:     {from: simulate_instrumented, run: sa0_y}
    expected: {fixture: expect_sa0_y}
```

**Never hardcode a fault id.** Ids are assigned in enumeration order and move
whenever a design's assignments change. The `{from, array, where, take}` form
resolves one record from an earlier operation's JSON artifact: equality only,
values compared as strings, and it must match **exactly one** record.

A design that assigns the same signal in several branches (an `if`/`else`
reset, a `case` with one target) produces several faults sharing
`{signal, bit, type}`, so a selector on those three is ambiguous. Either add
`line` to the `where` clause, or write the design with one assignment per
signal — the corpus prefers the latter, because line numbers move.

**Golden equivalence is mandatory.** Every behavioral design must assert that
the instrumented design with the fault selection disabled reproduces the
original RTL exactly. If that fails, instrumentation is behaviorally wrong even
though its output parses.

**Derive oracles, never copy them.** Work the expected values out from the
instrumentation semantics — a 1-bit location is forced to a literal, a wider
one is `rhs | (1 << bit)` or `rhs & ~(1 << bit)` — and then confirm they match.
Pasting simulator output into an oracle proves only that the simulator is
deterministic.

**An undetected fault is a result, not a failure.** State it positively, with
`trace_equal` against the reference.

## Worked example: a future C++ flow

Illustrative only — nothing below is wired into a pipeline. It shows that
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

`trace_equal` compares an RTL trace against a C++ trace unchanged — it only
ever knew how to compare two artifacts.
