// All three reduction operators over one vector, plus a multi-bit masked copy.
// The 1-bit reductions and the 8-bit `masked` output give this design both
// literal-forced and bit-masked fault locations in the same module.
module reduction_ops(input [7:0] d, output all_ones, output any_one, output parity, output [7:0] masked);
  assign all_ones = &d;
  assign any_one  = |d;
  assign parity   = ^d;
  assign masked   = d & 8'hF0;
endmodule
