// Half adder - the leaf of hier_adder's two-level hierarchy.
module half_adder(input a, input b, output sum, output carry);
  assign sum   = a ^ b;
  assign carry = a & b;
endmodule
