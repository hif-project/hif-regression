// A level-sensitive latch: the one storage element in this corpus that is not
// clocked.
//
// The `if` is deliberately incomplete. That incompleteness *is* the design -
// with no else branch, `q` holds its value while `en` is low - and it is the
// property a toolchain is most likely to normalise away, because completing a
// conditional is a legitimate transformation everywhere it does not create
// storage. A lowering that supplied an else branch, or that rebuilt the
// sensitivity list as if the process were a function of its inputs alone,
// produces combinational logic: still valid Verilog, still the same ports,
// and no memory.
//
// Distinct from the accidental latch merged_case_labels guards against. There
// the hold is the failure; here it is the specification.
module latch_enable(input en, input [3:0] d, output reg [3:0] q);
  always @(*) begin
    if (en) q = d;
  end
endmodule
