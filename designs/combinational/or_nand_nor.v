// The remaining two-input boolean operators, as separate outputs so each has
// its own assignment - and therefore its own fault location.
module or_nand_nor(input a, input b, output y_or, output y_nand, output y_nor);
  assign y_or   = a | b;
  assign y_nand = ~(a & b);
  assign y_nor  = ~(a | b);
endmodule
