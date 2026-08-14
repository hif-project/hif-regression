// The same child instantiated four times - each instance is a separate
// occurrence in the hierarchy, not a shared one.
//
// Each instance drives its own scalar wire, which are then gathered into the
// output vector. Connecting an instance output directly to a bit-select
// (`.y(y[0])`) currently crashes hif2verilog - see
// docs/findings/2026-08-14-backend-codegen.md (finding 1), which covers
// bit-selects used as assignment targets in general.
module top(input [3:0] a, input [3:0] b, output [3:0] y);
  wire y0, y1, y2, y3;

  bitslice u0(.a(a[0]), .b(b[0]), .y(y0));
  bitslice u1(.a(a[1]), .b(b[1]), .y(y1));
  bitslice u2(.a(a[2]), .b(b[2]), .y(y2));
  bitslice u3(.a(a[3]), .b(b[3]), .y(y3));

  assign y = {y3, y2, y1, y0};
endmodule
