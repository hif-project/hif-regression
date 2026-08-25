// Bit-select targets inside a process: `q[0] <= d0` rather than
// `assign y[0] = ...`. A different path from bit_select_assign.v - a
// procedural assignment keeps the Member as its target where a continuous one
// has to become a partial driver - and the path where the bit-select splitting
// fixes hif-frontend#9 and hif-frontend#23 live.
//
// The whole-vector reset write shares the register with the four per-bit
// writes, which is what a splitting pass has to reconcile: `q` cannot be split
// into four independent signals without the reset branch driving all four.
//
// `q[3] <= q[2]` puts a bit-select on both sides, so the same construct is
// exercised as a source and not only as a target, and it makes the bits
// depend on each other: a bit written from the wrong index is not merely a
// wrong bit, it is a wrong bit one cycle later as well.
//
// This is the behavioral half of the pair. bit_select_assign.v is round-trip
// only, which is what covers the continuous form's regeneration surviving a
// reparse; here the regenerated process is the source verbatim, so nothing but
// the values can say whether a future splitting pass got the indices right.
module procedural_bit_select(input clk, input rst, input d0, input d1, output reg [3:0] q);
  always @(posedge clk) begin
    if (rst) begin
      q <= 4'b0000;
    end else begin
      q[0] <= d0;
      q[1] <= d1;
      q[2] <= d0 ^ d1;
      q[3] <= q[2];
    end
  end
endmodule
