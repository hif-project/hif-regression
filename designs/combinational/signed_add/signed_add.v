// Signed addition, with the result taken at two widths: one that holds the
// sum and one that truncates it.
//
// *** THIS DESIGN CURRENTLY FAILS, DELIBERATELY. ***
//
// hif2verilog drops `signed` from every port and widens the operands by *zero*
// extension - `sum <= {1'b0, a} + {1'b0, b}` - so a negative sum comes out as
// a large positive number. hif-backend#81.
//
// verilog2hif records the signedness correctly: the HIF carries
// signed="true" on the port's BITVECTOR. The loss is entirely in the backend,
// and it is silent - exit 0, valid Verilog, reparses cleanly, different
// numbers.
//
// The corpus is full of arithmetic and had nothing that says an adder knows
// its operands are signed. This is that design, and it is red.
module signed_add(input signed [3:0] a, input signed [3:0] b, output signed [4:0] wide, output signed [3:0] narrow);
  assign wide   = a + b;
  assign narrow = a + b;
endmodule
