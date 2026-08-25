// The arithmetic right shift, `>>>`, next to the logical one for contrast.
//
// *** THIS DESIGN CURRENTLY FAILS, DELIBERATELY. ***
//
// hif2verilog prints `>>>` using HIF's internal operator name:
//
//   y_arith <= a sra {5'b00000, amt};
//
// which is not Verilog - hif-backend#82. The logical `>>` beside it comes out
// correctly, which is what makes the pair worth keeping in one design: the
// failure names the operator rather than the shift machinery.
//
// This design is also subject to hif-backend#81, which drops `signed` from the
// ports, so even once the operator prints it will need the signedness to be
// preserved to give the right answer. The two are independent and both filed;
// the operator spelling is what stops the output parsing at all, and is the
// declared failure here.
module arithmetic_shift_right(input signed [7:0] a, input [2:0] amt, output signed [7:0] arith, output [7:0] logical);
  assign arith   = a >>> amt;
  assign logical = a >>  amt;
endmodule
