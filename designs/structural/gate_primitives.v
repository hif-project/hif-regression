// One instance of each supported primitive gate, each driving its own output,
// so a fault on any single gate is independently observable.
module gate_primitives(input a, input b, output y_and, output y_or, output y_nand,
                       output y_nor, output y_xor, output y_not);
  and  g_and (y_and,  a, b);
  or   g_or  (y_or,   a, b);
  nand g_nand(y_nand, a, b);
  nor  g_nor (y_nor,  a, b);
  xor  g_xor (y_xor,  a, b);
  not  g_not (y_not,  a);
endmodule
