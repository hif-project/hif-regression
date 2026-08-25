// Mask, then invert. The intermediate is a multi-bit internal wire, which is
// where this differs from every other Muffin design here.
//
// The corpus already injects into internal signals, but only narrow ones that
// arrive by another route: struct_mux's `nsel` is one bit out of a gate
// primitive, hier_adder's `s1` is one bit left behind by an inlined instance,
// and pipeline3's `s1` is a register whose effect reaches the output cycles
// later. `sel` here is an ordinary eight-bit combinational wire written by a
// continuous assignment, and its effect reaches y in the same delta.
//
// The property under test is that the two locations are genuinely different
// points in the dataflow, not two names for one. Because the second statement
// inverts, the SAME fault type at the two locations drives the output the
// OPPOSITE way: forcing sel[N] high drives y[N] low, while forcing y[N] high
// drives it high. An instrumentation that collapsed the intermediate - injecting
// on y in both cases - would emit valid RTL in which both faults agree.
module mask_invert(input [7:0] data, input [7:0] mask, output [7:0] y);
  wire [7:0] sel;
  assign sel = data & mask;
  assign y   = ~sel;
endmodule
