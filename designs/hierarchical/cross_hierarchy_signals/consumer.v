// Consumes signals that originated in a sibling subtree.
module consumer(input [3:0] din, input flag, output [3:0] dout);
  assign dout = flag ? 4'd0 : din;
endmodule
