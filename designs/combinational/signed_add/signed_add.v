// Signed addition, with the result taken at two widths: one that holds the
// sum and one that truncates it.
//
// This used to fail, on hif-backend#81: hif2verilog dropped `signed` from every
// port and widened the operands by *zero* extension -
// `sum <= {1'b0, a} + {1'b0, b}` - so a negative sum came out as a large
// positive number. It now keeps `signed` and replicates the sign bit.
//
// verilog2hif recorded the signedness correctly: the HIF carries
// signed="true" on the port's BITVECTOR. The loss was entirely in the backend,
// and it was silent - exit 0, valid Verilog, reparses cleanly, different
// numbers.
//
// The corpus is full of arithmetic and had nothing that says an adder knows
// its operands are signed. This is that design.
module signed_add(input signed [3:0] a, input signed [3:0] b, output signed [4:0] wide, output signed [3:0] narrow);
  assign wide   = a + b;
  assign narrow = a + b;
endmodule
