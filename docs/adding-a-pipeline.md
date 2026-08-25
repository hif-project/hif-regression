# Adding a pipeline

Read [concepts.md](concepts.md) first if you have not — a pipeline is an ordered
list of operations of three kinds, and the terms below come from there.

## The change

Add an ordered `operations` list to `manifests/pipelines.yaml`:

```yaml
my_pipeline:
  operations:
    - {id: frontend,   kind: tool, use: verilog2hif}
    - {id: regenerate, kind: tool, use: hif2verilog}
    - {id: reparse,    kind: tool, use: verilog2hif}

    - id: simulate_regenerated
      kind: simulation
      use: iverilog
      sources: [{from: regenerate}, {fixture: testbench}]
      top: "{name}_tb"
      runs: [{id: regenerated}]

    - {id: validate, kind: validation, cases: {from_spec: expectations}}
```

Then either make it a category default under `suite_defaults`, or select it per
design with a `"pipeline"` key in `design.json`.

No code changes. If you find yourself wanting one, the invocation *model* is
probably new — see [adding-a-tool.md](adding-a-tool.md).

## Source and input references

- `{from: <id>}` — the artifact produced by an earlier operation
- `{fixture: <role>}` — a per-design file named by role in `design.json`
- `{design: sources}` — the design's own source files
- `inputs: [<id>]` on a tool — consume a named earlier operation instead of the
  immediate predecessor

## Fault selection, for Muffin pipelines

**Never hardcode a fault id.** Ids are assigned in enumeration order and move
whenever a design's assignments change. Resolve one from an earlier operation's
JSON artifact:

```yaml
runs:
  - {id: golden, params: {mut: 0}}
  - id: sa0_y
    params:
      mut: {from: enumerate, array: faults, where: {signal: y, bit: 0, type: stuck-at-0}, take: id}
```

Equality only, values compared as strings, and it must match **exactly one**
record. A design that assigns the same signal in several places — an `if`/`else`
chain, a vector built a bit or a slice at a time — produces several faults
sharing `{signal, bit, type}`, so such a selector is ambiguous. Add `line` to
the `where` clause to say which assignment.

Both shapes are wanted. Most designs should keep one assignment per signal,
because line numbers move and a selector naming one is fragile. But a fault
location **is** an assignment rather than a signal, and for a long time no
fixture said so: `counter_load`, `pipeline3` and `param_counter` each carry a
comment explaining that they were written with a single assignment *in order to*
keep the selector unambiguous, which meant the multi-location case went
untested. `nibble_swap`, `priority_arbiter`, `bit_reverse` and
`saturating_counter` cover it now, and each says in its header that its line
numbers are load-bearing.

Three things follow from a location being an assignment, and each of those
designs pins one: a location's `width` is the assignment's width, so `bit` on a
part-select counts from the slice (bit 0 of `y[7:4]` is `y[4]`, not `y[0]`); a
one-bit assignment to one bit of a wider vector is injected as a literal and
must leave its siblings alone; and a fault inside a branch is inert until that
branch runs.

One shape has no fixture: split the target across *continuous* assignments
(`assign y[7:4] = ...; assign y[3:0] = ...;`) and both locations come back with
`line: 0` and an empty `source`, identical in every field, so neither can be
named at all — hif-muffin#24. An unresolvable selector raises before any
simulation runs, so it aborts the suite rather than producing an expected
failure; there is deliberately no design in that form.

**Golden equivalence is mandatory.** Every Muffin behavioral design must assert
that the instrumented design with the fault disabled reproduces the original RTL
exactly. If that fails, instrumentation is behaviorally wrong even though its
output parses.

**Derive oracles, never copy them.** Work expected values out from the
instrumentation semantics — a 1-bit location is forced to a literal, a wider one
is `rhs | (1 << bit)` or `rhs & ~(1 << bit)` — then confirm they match. Pasting
simulator output into an oracle proves only that the simulator is deterministic.

**An undetected fault is a result, not a failure.** State it positively, with
`trace_equal` against the reference.
