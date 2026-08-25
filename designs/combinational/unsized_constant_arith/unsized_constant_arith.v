// Arithmetic against unsized constants, where the width of the *target* is
// what decides the answer.
//
// `a + 1` is not one expression here but two. Assigned to four bits it wraps -
// 15 + 1 is 0 - and assigned to five it does not - 15 + 1 is 16. Verilog gets
// that from the width of the assignment context, not from the operands, and
// an intermediate representation that fixed the expression's width where it
// was written, or that sized the literal to its operand, produces valid
// Verilog that disagrees on exactly one input.
//
// `a * 2` is the same rule under a different operator, where the overflow is
// two bits rather than one.
//
// No shifts: `d << 2` against an unsized amount still regenerates as
// unparsable Verilog (hif-backend#18), which is why shifter.v writes its fixed
// amount as `3'd2`. The addition and the multiplication reach the width rule
// without going near that.
module unsized_constant_arith(input [3:0] a, output [3:0] inc, output [4:0] wide_inc, output [3:0] dbl);
  assign inc      = a + 1;
  assign wide_inc = a + 1;
  assign dbl      = a * 2;
endmodule
