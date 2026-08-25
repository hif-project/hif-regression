// A bit-select whose index is a signal rather than a constant: `d[idx]`.
//
// Every other bit-select in this corpus - concat_slice, the assignment-target
// designs, the reduction fixtures - indexes with a literal, which a tool can
// resolve while building the tree. A dynamic index cannot be resolved that
// way: it has to survive as an expression and be evaluated at run time, and a
// lowering that folded it to a fixed bit, or that reversed the index, produces
// a design that still parses and still has one output bit.
//
// The second output puts the dynamic select next to a constant one in the same
// concatenation, so the two index kinds have to coexist in one expression
// rather than each getting its own assignment.
module slice_dynamic_index(input [7:0] d, input [2:0] idx, output bit_at, output [1:0] pair);
  assign bit_at = d[idx];
  assign pair   = {d[idx], d[0]};
endmodule
