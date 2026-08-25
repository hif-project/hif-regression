// Continuous assignment straight to a vector bit-select, one bit at a time.
//
// hif-backend#17 crashed hif2verilog on `assign y[0] = ...`, and hif-backend#23
// was the fix: an assignment target reached through a Member had to be resolved
// via its terminal prefix before the driver for it could be built. Until then
// the corpus could not contain this construct at all - carry_ripple.v still
// gathers its sum bits into one whole-vector assignment for exactly that
// reason - so nothing here ever drove the per-bit path.
//
// Every bit of `y` is driven, each from a different expression, so a bit lost
// on the way through HIF is a lost value and not merely a lost line. The
// regeneration is not bit-for-bit source: each bit-select target becomes its
// own partial-driver register written from its own process, which is the
// lowering this fixture is here to keep working.
module bit_select_assign(input [3:0] a, input [3:0] b, output [3:0] y);
  assign y[0] = a[0] & b[0];
  assign y[1] = a[1] | b[1];
  assign y[2] = a[2] ^ b[2];
  assign y[3] = ~a[3];
endmodule
