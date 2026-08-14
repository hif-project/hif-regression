# Simulation and validation as first-class regression concepts

Date: 2026-08-14
Status: approved, pending implementation

## Problem

`hif-regression` proves that the HIF toolchain *transforms* designs without
crashing. It does not prove that the transformed designs still *behave*
correctly.

For Muffin this gap is significant. Today's `muffin_roundtrip` pipeline shows
that Muffin can enumerate faults, instrument a design, and that the resulting
HIF regenerates into parsable Verilog. It says nothing about whether
instrumentation preserved the original behavior, nor whether an activated
stuck-at fault does what it claims. A Muffin that emitted structurally valid
but behaviorally wrong Verilog would pass the current suite.

We want to be able to state: *Muffin-generated Verilog was actually simulated,
golden mode preserved RTL behavior, and selected SA0/SA1 faults were activated
and produced the expected behavioral results.*

Muffin is the motivating case, not the design constraint. The architecture must
express any "transform, then run, then check" flow without engine changes.

## Scope

In scope: a generic execution model for three distinct operation kinds; an
expanded curated corpus; real simulation-based Muffin acceptance tests;
structured behavioral reporting; documentation.

Out of scope: changing HIF product semantics; a DAG scheduler; vendoring or
building a simulator inside this repo; cocotb or comparable frameworks;
implementing the future DDT/A2Tool flow.

## Three concepts, kept distinct

The core requirement is that these never collapse into one another:

| Concept | Consumes | Produces | Asserts |
|---|---|---|---|
| **tool** | artifacts | artifacts | nothing |
| **simulation** | sources + stimulus | result artifacts (traces) | nothing |
| **validation** | result artifacts | a verdict | yes |

A simulation that also decided pass/fail would hide *why* a behavioral test
failed. A validator that also ran a simulator could not be reused across
simulators. Keeping them separate is what makes the failure attribution in the
reporting section possible at all.

## Execution model

### Ordered operations, not a DAG

`pipelines.yaml` moves from `steps` + `probes` to a single ordered
`operations` list. Operations execute strictly top to bottom. There is no
topological sort, no dependency resolution, no parallelism, and no scheduler.

Each operation has:

- `id` — unique within the pipeline, independent of the implementation name.
  Doubles as the stage key in the JSON report.
- `kind` — `tool`, `simulation`, or `validation`.
- `use` — an entry in the registry for that kind.

Input references are explicit but defaulted: an operation with no input
reference consumes the previous operation's artifact. This preserves today's
terse spelling for linear pipelines while letting a validator name exactly
which two earlier results it compares.

`steps`/`probes` are migrated, not dual-supported. Encountering either key
raises a diagnostic naming the replacement. The repo is young enough that
carrying two syntaxes costs more than it saves.

### Why probes disappear

A probe was a tool operation that consumed a named earlier step's artifact
instead of its predecessor's. Under `operations` that is just an operation with
an explicit input reference, so the concept is subsumed rather than removed:

```yaml
- {id: muffin_list_faults, kind: tool, use: muffin_list_faults, inputs: [frontend]}
```

Probe operations keep their existing ids *and their existing position* — after
the main steps, not interleaved — so report stage keys and their order stay
identical across the migration. `muffin_roundtrip` therefore becomes
`frontend, backend, reparse, muffin_list_faults, muffin_instrument`, with the
last two taking `inputs: [frontend]`.

One behavior change is deliberate: probes used to run only after every main
step passed, and a probe failure did not affect main steps. Under `operations`
a failed operation stops the pipeline like any other. This is stricter, and
correct — the old carve-out existed only because probes were bolted on.

## Manifest schemas

### Tools (`manifests/tools.yaml`)

Unchanged.

### Simulators (`manifests/simulators.yaml`)

A simulator has an optional compile/elaborate phase and a run phase. Splitting
them is what makes compile-once/run-many possible, which matters directly: a
Muffin design carries every fault in one instrumented netlist, so recompiling
per fault would be pure waste.

```yaml
iverilog:
  language: verilog
  compile:
    command: ["iverilog", "{options}", "{defines}", "-o", "{workdir}/sim.vvp",
              "-s", "{top}", "{sources}"]
    artifact: "{workdir}/sim.vvp"
    options: ["-g2005"]
  run:
    command: ["vvp", "{compiled}", "{params}", "+trace={trace}"]
    artifact: "{rundir}/trace.csv"
    param_template: "+{key}={value}"
  timeout_s: 60
```

`-g2005` is sufficient: `hif2verilog` renders Muffin's activation port as
`input wire [31:0] muffinMutPort`, a legal Verilog-2001 port. This was verified
against real generated output, not assumed.

The registry describes only *how to invoke* `iverilog`/`vvp`. Binaries resolve
through the existing `find_tool` PATH lookup. Provisioning the simulator is the
environment's job (apt in CI, whatever is installed locally); this repo never
installs, builds, vendors, or version-pins a simulator.

### Validators (`manifests/validators.yaml`)

```yaml
trace_equal:    {impl: artifact_equal}
trace_differs:  {impl: artifact_differs}
expected_trace: {impl: artifact_equals_fixture}
```

`impl` selects one of a small set of generic comparators in
`scripts/validators.py`. Adding a validator is normally a manifest line; a new
`impl` is written only when the comparison logic is genuinely new.

### Placeholder semantics

Fixed and documented. Generalizes the `{inputs}` special case that already
exists in `build_argv`.

- **Scalar** — substituted within a token:
  `{input}` `{workdir}` `{name}` `{top}` `{compiled}` `{trace}` `{rundir}`
- **List** — must be the *entire* token; expands to zero or more argv entries:
  `{inputs}` `{sources}` `{defines}` `{params}` `{options}`

A list placeholder appearing inside a larger token is a manifest error, not a
silent string coercion. Unknown placeholders are errors naming the operation
and the offending token.

## Simulation operations

```yaml
- id: simulate_instrumented
  kind: simulation
  use: iverilog
  sources: [{from: regenerate}, {fixture: testbench}]
  top: "{name}_tb"
  defines: [MUFFIN_MUT]
  runs: {from_spec: runs}
```

`sources` entries are one of `{from: <op_id>}` (an earlier operation's
artifact), `{fixture: <name>}` (a per-design fixture), or `{design: sources}`
(the design's own sources).

`runs` is either a literal list or `{from_spec: <key>}`, which reads the list
from the design's `behavior.yaml`. This is what lets one shared pipeline serve
many designs whose fault cases differ. The engine performs a list lookup; it
attaches no meaning to the contents.

Each run gets its own `{rundir}` and its own `{trace}` artifact. One compile
precedes all runs.

## Declarative fault selection

Fault IDs are assigned in enumeration order (`FaultEnumerator.cpp`), so they
move whenever a design's assignments change. Hardcoding them would make the
corpus fragile in a way that has nothing to do with correctness.

A run parameter is therefore either a literal or a generic JSON record lookup:

```yaml
params:
  mut: {from: enumerate, array: faults, where: {signal: y, bit: 0, type: stuck-at-0}, take: id}
```

Semantics, deliberately minimal:

- `from` names an earlier operation whose artifact is a JSON document.
- `array` is the key holding a list of objects.
- `where` is an equality filter. All values compare as strings (`str(a) ==
  str(b)`), so `bit: 0` matches JSON `0` without type-coercion surprises.
- `take` is the field to extract.
- The filter must match **exactly one** record. Zero or multiple matches is a
  hard error reporting the operation, the filter, and the candidates found.

No operators, no nesting, no expressions. This is a record lookup, not a query
language. The engine knows "find one object in a JSON array and take a field"
and nothing about faults.

## Validation operations

```yaml
- id: validate
  kind: validation
  cases: {from_spec: expectations}
```

A case names its validator and its operands:

```yaml
- {id: golden_matches_rtl, use: trace_equal,
   left: {from: simulate_reference, run: reference},
   right: {from: simulate_instrumented, run: golden}}
```

Operand references are `{from: <sim_op>, run: <run_id>}` or `{fixture: <name>}`
for a checked-in oracle. Per-case validator selection is what expresses
detected vs undetected without a special mechanism.

## Corpus organization

Behavioral testing is an **orthogonal capability**, not a design category. A
combinational AND, a sequential counter and a hierarchical design can each be
behavioral. There is no `designs/behavioral/` directory, and no design is
duplicated in order to be simulated.

A design gains behavioral coverage by moving from single-file to directory
form inside its existing category:

```
designs/combinational/and2/
  and2.v            # RTL
  and2_tb.v         # stimulus, shared by both compiles
  design.json       # DUT: top, pipeline, sources, fixtures
  behavior.yaml     # runs (fault selection) + expectations (oracle)
```

`design.json` gains optional `sources` and `fixtures` so a testbench is never
mistaken for a design source:

```json
{"top": "and2", "pipeline": "muffin_behavioral",
 "sources": ["and2.v"], "fixtures": {"testbench": "and2_tb.v"}}
```

Target: **48 designs, 11 of them behavioral.**

| Category | Designs | Behavioral |
|---|---|---|
| combinational | 16 | 4 |
| sequential | 13 | 4 |
| parameterized | 7 | 1 |
| hierarchical | 6 | 1 |
| structural | 6 | 1 |

Every design stays small, deterministic, readable, and uses only constructs
already in the accepted frontend subset. No construct is added merely to
inflate the count.

## Stimulus, selection, and expectation

`behavior.yaml` keeps the three concerns separate, because they are three
different things:

- **Stimulus** lives in the testbench fixture and is shared by both compiles.
- **Runtime fault selection** is `runs`.
- **Expected result** is `expectations`.

```yaml
runs:
  - {id: golden, params: {mut: 0}}
  - {id: sa0_y,  params: {mut: {from: enumerate, array: faults,
                                where: {signal: y, bit: 0, type: stuck-at-0}, take: id}}}
expectations:
  - {id: golden_matches_rtl, use: trace_equal,
     left: {from: simulate_reference, run: reference},
     right: {from: simulate_instrumented, run: golden}}
  - {id: sa0_y_detected, use: expected_trace,
     left: {from: simulate_instrumented, run: sa0_y},
     expected: {fixture: expect_sa0_y}}
  - {id: sa1_y_undetected, use: trace_equal,
     left: {from: simulate_instrumented, run: sa1_y},
     right: {from: simulate_reference, run: reference}}
```

An undetected fault is an explicit positive expectation — `trace_equal` against
the reference — never a tolerated failure. Fault simulation legitimately
produces undetected faults under a given stimulus; the corpus states which.

### One testbench, two compiles

The instrumented top gains `muffinMutPort`, so a single testbench connects it
conditionally:

```verilog
dut u_dut (.a(a), .b(b), .y(y)
`ifdef MUFFIN_MUT
  , .muffinMutPort(mut)
`endif
);
```

The instrumented simulation declares `defines: [MUFFIN_MUT]`. The stimulus is
written once and drives both. Runtime selection arrives by plusarg; the trace
path likewise, so each run writes its own artifact.

Traces are CSV: deterministic, diffable, readable, and trivially emitted by
`$fdisplay`. Structured output beats parsing human-oriented stdout.

## Reporting

Every operation record carries `kind` and `phase`, so the four failure
locations are distinguishable by construction rather than by parsing:

| Phase | Meaning |
|---|---|
| `execute` | tool execution |
| `compile` | simulator compilation/elaboration |
| `run` | simulation execution |
| `validate` | validation |

`FAIL` joins the status vocabulary, produced by validation only. Severity
ordering becomes `PASS < CLEAN_REJECT < TIMEOUT < FAIL < CRASH`. Tool
classification is untouched, so existing curated and external classifications
are unaffected.

The JSON report gains a `behavioral` section: design, pipeline, simulation
case, fault selection, resolved fault ID, validator, status, and a capped
mismatch excerpt. The Markdown summary shows counts plus failing cases only —
full traces stay in the JSON artifact, never in the GitHub summary.

Existing structural and external reporting is unchanged.

## Extensibility check

The future flow `Verilog -> frontend -> DDT -> A2Tool -> C++ backend ->
compile/run C++ -> compare against RTL simulation` is expressible with no
engine change:

- `ddt`, `a2tool`, `hif2cpp` are `tools.yaml` entries.
- A `cxx_binary` simulator has `compile` = `g++`, `run` = the produced
  executable. The compile/run split already models this.
- `trace_equal` compares the RTL trace against the C++ trace, unchanged.

This ships as a commented, non-wired worked example in the documentation.

Adding a new simulator or validator is a manifest addition, plus a generic
executor or comparator implementation only where the mechanism is intrinsically
new. No HIF tool ever gets a branch in the engine.

## Validation plan

1. Repository CTest suites, as currently run.
2. Curated regression before and after the engine refactor, compared per design
   and per stage. The pre-refactor baseline is already captured: 12 designs, all
   PASS, stage keys recorded.
3. The expanded curated corpus, structurally.
4. The Muffin behavioral subset.
5. Confirmation that every original fixture still passes.
6. A grep proving no product-specific branch (`if tool == "muffin"` or
   equivalent) exists in the generic engine.
7. The extensibility example above.

External benchmarks get a targeted smoke check only; their code and manifests
are untouched, so a full rerun would cost hours and prove nothing.

## Constraints

Curated regression failures are real failures. Expectations are never weakened
to accommodate a fixture that turns out to be wrong — the fixture gets fixed.

If a genuine Muffin behavioral bug surfaces, work stops before any change to
`hif-muffin` and the finding is reported with a smallest reproducer, expected
versus actual behavior, the relevant generated artifacts, and the likely
defective layer. Establishing trustworthy coverage comes first; silently
repairing what that coverage uncovers would defeat the purpose.

## Recorded observation

`assign y = a & b` regenerates as `output reg y` with a non-blocking assignment
inside `always @(a, b)`. This is legal and simulates correctly under the trace
sampling used here, but it is a backend style choice worth noting. Not a defect,
not in scope.
