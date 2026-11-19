// Vectors whose range does not run down to bit 0. `[0:7]` runs up: its low-order bits
// are at the right-hand end, indices 4 to 7, and Verilog rejects a part-select against
// the declared direction. `[11:4]` runs down, but not to 0, and is the control: it is
// declared [7:0] on the way back, whatever its bounds were, so its low-order select
// stays [3:0].
//
// `sp` is a signed ascending vector. Its sign bit is its LEFT end, index 2, and widening it
// replicates that bit: sp[7] is the least significant bit but one.
//
// hif-backend#91 made declarations keep an ascending range. The part-select a
// truncating assignment needs, which was always printed [width-1:0], then no longer
// matched the declaration - `a[3:0]` on a `[0:7]` - and the file did not compile.
module ascending_vectors(
    input  [0:7] a,
    input  [0:3] b,
    input  [11:4] c,
    input  signed [2:9] sp,
    output [0:3] trunc_up,
    output [0:7] widen_up,
    output [0:7] sum_up,
    output [3:0] trunc_offset,
    output signed [11:0] sext_up
);
  assign trunc_up     = a;
  assign widen_up     = b;
  assign sum_up       = a + b;
  assign trunc_offset = c;
  assign sext_up      = sp;
endmodule
