// A full adder built from two half adders, so the interesting logic
// originates in a child module rather than in the top level.
//
// This is the behavioral hierarchy fixture. It was demoted to structural-only
// when it first failed golden equivalence: hif2verilog hoisted each
// frontend-generated logic cone into its own process, so the process
// computing `sum` kept a sensitivity list of (cin, a, b) - the transitive
// inputs - while the `s1` it actually reads was written by a different
// process, and could be read stale.
//
// Fixed in hif-backend#16 (cones are now emitted at their call site, inside
// the process that reads them), and restored to muffin_behavioral here. The
// full 8-vector truth table and the fault on s1 are back.
//
// Instance wiring is a separate matter: verilog2hif inlines instances, so
// Muffin never sees a hierarchy here at all -
// https://github.com/hif-project/hif-muffin/issues/10.
module hier_adder(input a, input b, input cin, output sum, output cout);
  wire s1, c1, c2;

  half_adder u_ha1(.a(a),  .b(b),   .sum(s1),  .carry(c1));
  half_adder u_ha2(.a(s1), .b(cin), .sum(sum), .carry(c2));

  assign cout = c1 | c2;
endmodule
