// Signed relational comparison - a different path from signed arithmetic, and
// the one where the answer is a single bit that is simply the wrong way round.
//
// *** THIS DESIGN CURRENTLY FAILS, DELIBERATELY. ***
//
// hif2verilog drops `signed` from the ports (hif-backend#81), so `a < b`
// becomes an unsigned comparison of the same bit patterns. Every row with
// exactly one negative operand inverts: -1 < 1 is true signed and false
// unsigned, because 4'b1111 is 15.
//
// signed_add covers the arithmetic side of the same defect. This is the
// relational one: it is kept separate because the operators are different code
// in the emitter and because the failure looks different - a sum that is
// wrong by a large amount against a boolean that is simply inverted.
module signed_compare(input signed [3:0] a, input signed [3:0] b, output lt, output ge, output eq);
  assign lt = (a <  b);
  assign ge = (a >= b);
  assign eq = (a == b);
endmodule
