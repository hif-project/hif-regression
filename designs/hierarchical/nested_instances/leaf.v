// Innermost level: a single gate.
module leaf(input a, input b, output y);
  assign y = a & b;
endmodule
