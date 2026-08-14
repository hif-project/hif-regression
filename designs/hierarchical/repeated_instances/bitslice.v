// One bit of a wider function, instantiated several times by the parent.
module bitslice(input a, input b, output y);
  assign y = a ^ b;
endmodule
