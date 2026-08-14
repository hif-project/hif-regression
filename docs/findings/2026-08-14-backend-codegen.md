# Two hif-backend / hif-core defects found by corpus expansion

Date: 2026-08-14
Found by: writing new curated combinational fixtures (`carry_ripple`, `shifter`)
Status: **reported, not fixed** — this repo reproduces and classifies toolchain
bugs, it does not patch them (see README "Non-goals").

Both were found by ordinary, legal Verilog-2001 that the frontend accepts
without complaint. Neither is an unsupported-construct rejection: the frontend
parses both, and the failure appears later.

---

## Finding 1 — bit-select on the LHS of a continuous assignment crashes the backend

**Reproducer** (3 lines):

```verilog
module bug1(input a, input b, output [1:0] sum);
  assign sum[0] = a ^ b;
  assign sum[1] = a & b;
endmodule
```

**Command:**

```sh
verilog2hif -o bug1 bug1.v     # OK
hif2verilog bug1.hif.xml -D r1 # crash, exit 1
```

**Expected:** Verilog emitted for a design that assigns individual bits of an
output vector.

**Actual:** an assertion failure inside hif-core, reached from hif2verilog's
code generation:

```
[HIF] [setDeclaration] ASSERT: Passed non-symbol object
- Raised by hif-core/src/semantics/setDeclaration.cpp:33
- Source file info - bug1.v: line 2, column 14
  -- in Process: globact_process_0
  -- in Design Unit: bug1

Object: Member
(MEMBER (no name) (IDENTIFIER sum) (INT_VALUE (no name) 0))

Parent #1:
(ASSIGN (no name) (MEMBER (no name) (IDENTIFIER sum) ...) (IDENTIFIER sum_partial0_0))

Object type: nullptr
Prefix type: nullptr
```

**Likely layer:** `hif-core` `semantics/setDeclaration.cpp` is the assertion
site, but the caller is the more likely culprit — something in the backend (or
in a standardization pass) hands a `Member` where a symbol is expected, and
both `Object type` and `Prefix type` are `nullptr`, suggesting the member's
semantic type was never resolved before the call. The frontend's own
`sum_partial0_0` temporary appears in the parent assign, so the partial-target
lowering is involved.

**Not classified as CLEAN_REJECT, correctly:** HIF's deliberate-rejection path
prints "is not supported"; this is an internal assertion, so the runner reports
CRASH. That is the intended conservative behavior.

**Workaround used in the corpus:** assign the whole vector once, keeping
intermediate carries as their own wires. `carry_ripple.v` does this — the
explicit carry chain, which is the point of the fixture, is preserved.

---

## Finding 2 — shift by an unsized constant regenerates as unparsable Verilog

**Reproducer** (3 lines):

```verilog
module bug2(input [7:0] d, output [7:0] y);
  assign y = d << 2;
endmodule
```

**Command:**

```sh
verilog2hif -o bug2 bug2.v      # OK
hif2verilog bug2.hif.xml -D r2  # OK, exit 0
verilog2hif -o rp r2/bug2.v     # syntax error
```

**Expected:** regenerated Verilog that reparses — this is the round-trip
property the whole `plain_roundtrip` pipeline exists to check.

**Actual:** hif2verilog exits 0 and emits:

```verilog
always @( d ) begin
    y <= {24'b000000000000000000000000, d} << 32'b00000000000000000000000000000010
        [7:0];
end
```

Reparsing fails with `syntax error at line 23, column 2`.

Two distinct problems in one line:

1. The `[7:0]` truncation is meant to apply to the *result* of the shift, but
   it is emitted with no parentheses immediately after the shift amount, so it
   reads as a part-select of the constant `32'b...10`.
2. Even parenthesised, `(expr)[7:0]` is not legal Verilog-2001 — a part-select
   applies to a net/variable, not to an arbitrary expression. Emitting this
   correctly needs a temporary, not just brackets.

**Likely layer:** `hif-backend` Verilog code generation — specifically whatever
emits a `Slice`/`Member` whose prefix is an expression rather than a symbol.
The unsized decimal `2` is what makes the expression 32 bits wide and forces
the truncation; the bug is in how that truncation is printed, not in the
widening itself.

**Trigger is narrow.** All of these round-trip cleanly:

| Variant | Result |
|---|---|
| `d << 3'd2` (sized constant) | OK |
| `d << amt` (variable amount) | OK |
| `d << two` where `two` is a `wire [2:0]` | OK |
| `assign s = {a & b, a ^ b}` | OK |
| 5-bit intermediate then `w[3:0]` / `w[4]` | OK |

So the defect needs an *unsized* constant shift amount producing a value wider
than the target.

**Workaround used in the corpus:** `shifter.v` uses a sized constant.

---

## Why these are not in the curated corpus as failing fixtures

The curated suite's contract is that a failure is a real regression. Parking
two permanently-CRASHing designs there would make CI red forever and train
everyone to ignore it — the opposite of the point.

The reproducers live here instead, minimal and runnable. If and when either
defect is fixed, the corresponding construct should be promoted back into
`designs/combinational/` as an ordinary fixture, and this section deleted.
