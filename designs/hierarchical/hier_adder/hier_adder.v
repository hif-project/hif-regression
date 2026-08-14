// A full adder built from two half adders, so the interesting logic
// originates in a child module rather than in the top level.
//
// Structural only for now. This design was written as the behavioral
// hierarchy fixture, and in that role it immediately failed golden
// equivalence: the regenerated Verilog is not behaviorally equivalent to this
// source, independently of Muffin. verilog2hif inlines the instances and
// hif2verilog then emits each assignment as its own process, giving the
// process that computes `sum` a sensitivity list of (cin, a, b) - the
// transitive inputs - while the `s1` it actually reads is written by a
// different process. `sum` can therefore be evaluated from a stale `s1`.
//
// See https://github.com/hif-project/hif-backend/issues/16. Promote this back
// to muffin_behavioral once that is fixed; the stimulus and oracle are
// straightforward to restore (full 8-vector truth table, fault on s1).
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
