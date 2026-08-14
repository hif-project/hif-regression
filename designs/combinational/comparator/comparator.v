// Three independent relational results over the same operands.
module comparator(input [3:0] a, input [3:0] b, output eq, output lt, output gt);
  assign eq = (a == b);
  assign lt = (a < b);
  assign gt = (a > b);
endmodule
