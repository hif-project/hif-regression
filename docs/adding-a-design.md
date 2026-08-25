# Adding a curated design

Everything you need to add a design to `designs/`, in one page. You should not
need to open another file, or read an existing design to work out the pattern.

- [Decide the shape](#decide-the-shape)
- [The simplest case: parse and round-trip only](#the-simplest-case-parse-and-round-trip-only)
- [Adding stimulus: the four behavioral shapes](#adding-stimulus-the-four-behavioral-shapes)
- [design.json](#designjson)
- [The testbench](#the-testbench)
- [behavior.yaml](#behavioryaml)
- [Verify it](#verify-it)
- [Designs that are expected to fail](#designs-that-are-expected-to-fail)
- [House rules](#house-rules)

## Decide the shape

Two questions, in this order.

**1. Which category?** `designs/combinational/`, `sequential/`,
`parameterized/`, `hierarchical/`, `structural/`. Pick by what the design *is*.
Behavioral coverage is not a category — a design gains it in place, never by
being duplicated into some `behavioral/` tree.

**2. Can the defect you care about be seen without running the design?**

| the defect shows up as | you need |
|---|---|
| a tool refusing, crashing, or emitting something that will not reparse | nothing extra — the default pipeline already catches it |
| a value, or a time, that is wrong while everything still parses | stimulus: a testbench and an oracle |

Most corpus designs are the first. Reach for the second when the broken output
would be *valid* HDL — that is precisely the class a round-trip check is blind
to.

## The simplest case: parse and round-trip only

Drop a single `.v` file in the category. That is the whole procedure — it
inherits the category's default pipeline (`plain_roundtrip`: parse, regenerate
HIF, regenerate HDL, reparse) and needs no sidecar at all.

```
designs/combinational/my_design.v
```

A `.vhd` design cannot be a bare file: discovery globs `*.v`, so VHDL always
needs directory form with an explicit `sources` list (below).

## Adding stimulus: the four behavioral shapes

A design with stimulus moves to directory form **inside its category**:

```
designs/combinational/my_design/
    my_design.v            the RTL
    my_design_tb.v         stimulus, shared by every compile in the pipeline
    design.json            top, pipeline, sources, fixtures
    behavior.yaml          runs + expectations
    expect_*.csv           oracles, when the pipeline needs one
```

Which pipeline depends on what you can compare against:

### `behavioral_roundtrip` — Verilog source, compare against itself

The strongest and the cheapest to write. The pipeline simulates the original
RTL and the regenerated RTL under the same testbench and requires **identical**
traces. No oracle file: the claim is "the round trip preserved behavior", and
checking in absolute values would freeze your testbench's stimulus into the
corpus as if it were the specification.

Use it for any Verilog design whose contract is behavioral.

### `vhdl_to_verilog` — VHDL source, compare against a checked-in trace

There is no VHDL simulator in this environment (no ghdl, no nvc, locally or in
CI), so a VHDL design's own source cannot be run. The pipeline simulates only
the regenerated Verilog and compares it against an expected trace you compute
**by hand from the VHDL** and check in.

This is deliberately the weaker form — it pins the values but takes your word
for what they should be — and it is the strongest check available on that path.
Derive the trace from the source semantics and then confirm the simulator
agrees. Capturing simulator output and blessing it proves only that the
simulator is deterministic.

### `verilog_to_vhdl` — Verilog source, all the way round and back

The Verilog-to-VHDL direction. There is no VHDL simulator here, so the emitted
VHDL cannot be run — but it can be brought back: Verilog → HIF → VHDL → HIF →
Verilog, then the twice-crossed Verilog is simulated against the untouched
original under the same testbench and required to match. Like
`behavioral_roundtrip` it needs no checked-in oracle, because the claim is "the
excursion through VHDL preserved behaviour".

Do not be tempted to stop at the VHDL and call the reparse a check. `vhdl2hif`
is more permissive than the VHDL LRM — it accepts a plain `variable` in an
architecture declarative region, where VHDL allows only `shared variable`, and
it accepts a `to_unsigned` call that resolves to no `numeric_std` overload — so
"the VHDL reparsed" is much weaker than it sounds. Both of those were measured,
not assumed; see hif-backend#94.

The cost is that a failure names one of four tools, which is what the stage ids
are for: `to_vhdl` is `hif2vhdl`, `to_verilog` is `hif2verilog` on the
twice-crossed HIF, and those are genuinely different defects. Get the
`expected_failure` stage right — hif-backend#93 and #94 both exit 0 from
`hif2vhdl` and fail two operations later.

### `muffin_behavioral` — fault instrumentation

Everything above plus Muffin: parse, enumerate faults, instrument, regenerate,
simulate the original RTL, simulate the instrumented netlist once per fault
selection, validate. See [adding-a-pipeline.md](adding-a-pipeline.md) for the
fault-selection rules, which are the fiddly part.

## design.json

```json
{
    "top": "my_design",
    "pipeline": "vhdl_to_verilog",
    "sources": ["my_design.vhd"],
    "fixtures": {
        "testbench": "my_design_tb.v",
        "expect_regenerated": "expect_regenerated.csv"
    },
    "note": "Why this design exists, and which issue it covers."
}
```

| key | when | notes |
|---|---|---|
| `top` | required in directory form | top-level module/entity name |
| `pipeline` | when it differs from the category default | see the four above |
| `sources` | **required in directory form** | without it the testbench is picked up as a design source |
| `fixtures` | when the pipeline references them | maps a *role* (`testbench`, `expect_*`) to a file, so one pipeline serves designs whose files are named differently |
| `note` | always, in practice | what the design is for. It is printed next to any failure, so write it for whoever hits that |
| `expected_failure` | only for a documented, filed bug | see [below](#designs-that-are-expected-to-fail) |

## The testbench

Read the trace path from a plusarg and write CSV. One compiled binary then
serves every run, and structured output beats parsing human-oriented stdout.

```verilog
`timescale 1ns/1ps
module my_design_tb;
  // ... ports ...
  integer fd;
  reg [4095:0] tracefile;   // size generously: a truncated path fails silently

  my_design dut (/* ... */);

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin $display("ERROR: cannot open trace file"); $finish; end
    $fdisplay(fd, "time,a,b,y");          // header

    // ... stimulus, with a $fdisplay after each step ...

    $fclose(fd);
    $finish;
  end
endmodule
```

Include `$time` in every row whenever timing is part of the claim — that is
what makes a trace comparison a timing comparison and not merely a value one.

For `muffin_behavioral` only, the activation port exists just in the
instrumented netlist, so connect it conditionally; the pipeline supplies the
define:

```verilog
dut u_dut (.a(a), .b(b), .y(y)
`ifdef MUFFIN_MUT
  , .muffinMutPort(mut)
`endif
);
```

**Give the design a second driver when the property needs one.** A bidirectional
pin, a shared bus, anything with contention: if the testbench is not itself the
other device, a lowering that drives unconditionally produces exactly the same
trace as a correct one and the design proves nothing.

## behavior.yaml

Three separate concerns, kept separate: stimulus lives in the testbench,
selection in `runs`, expectation in `expectations`.

Comparing a design against its own regenerated form:

```yaml
runs: []

expectations:
  - id: regenerated_matches_rtl
    use: trace_equal
    left:  {from: simulate_reference,   run: reference}
    right: {from: simulate_regenerated, run: regenerated}
```

Comparing against a checked-in trace (the VHDL case):

```yaml
runs: []

expectations:
  - id: regenerated_matches_vhdl
    use: expected_trace
    left:     {from: simulate_regenerated, run: regenerated}
    expected: {fixture: expect_regenerated}
```

`from:` names an operation `id` in the pipeline; `run:` names a run within it;
`fixture:` names a key from `design.json`'s `fixtures`.

Write the comment at the top of the file for the next reader: what the trace
pins, line by line, and why each line is a distinct failure mode rather than
repetition. A trace nobody can check is an oracle on trust.

## Verify it

Run just your design, against binaries you already have:

```sh
python3 scripts/run_regression.py --only my_design --bin-dir /path/to/bins
```

`--bin-dir` takes any directory holding the tool binaries — a directory of
symlinks into your sibling `hif-*/build` trees works, and avoids rebuilding the
whole toolchain to check one design. See [running.md](running.md).

**Then check that it discriminates.** A design added for a bug it cannot detect
is decoration. Rebuild the tool with the fix reverted, run the design again, and
confirm it fails. If you cannot easily do that, say so in the `note` rather than
implying coverage you have not demonstrated.

## Designs that are expected to fail

A curated design may be left failing **only** when it found a real bug that is
filed and still open. Declare it, so the corpus reports it as documented rather
than as a regression:

```json
"expected_failure": {"issue": "hif-frontend#31", "stage": "validate"}
```

Both keys are required. `issue` because an expected failure with no filed bug
behind it is just a disabled test. `stage` because "fails somewhere" is not a
claim worth pinning — a design that starts crashing in the frontend instead of
mismatching in validation has broken *differently*, and that must surface.

What the runner then does:

| outcome | verdict | exit |
|---|---|---|
| fails at the declared stage | `XFAIL`, listed apart from real failures | 0 |
| passes | `XPASS` — remove the key, the bug is fixed | 1 |
| fails at a different stage | its real status, flagged as not the documented failure | 1 |

**Never reshape a design so it stops finding a bug.** If a natural design
exposes a defect, that is the corpus working. Rewriting it until it passes makes
the suite green by making it stop asking the question. File the bug, declare the
expected failure, and leave the design alone.

## House rules

- **Small, real, and understood.** Hand-written fixtures the project owns
  completely, not a benchmark dump. Controlled semantic coverage, not quantity.
- **A clear input/output relationship.** A design whose correct behavior you
  cannot state in a sentence cannot serve as an oracle for anything.
- **One design per question.** Two defects in one fixture makes a failure harder
  to attribute; the pipeline stages are already designed so a failure names its
  own stage.
- **Say why it exists.** The `note` and the header comment should name the issue
  it covers and what would break if it regressed.
- **Never weaken an expectation to make something pass.**
