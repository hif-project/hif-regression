// Logical shifts by a variable amount, both directions, plus a fixed-amount
// shift for contrast.
//
// The fixed amount is written as a sized constant. An unsized `d << 2` widens
// the expression to 32 bits and currently regenerates as unparsable Verilog -
// see https://github.com/hif-project/hif-backend/issues/18.
module shifter(input [7:0] d, input [2:0] amount, output [7:0] left, output [7:0] right, output [7:0] fixed);
  assign left  = d << amount;
  assign right = d >> amount;
  assign fixed = d << 3'd2;
endmodule
