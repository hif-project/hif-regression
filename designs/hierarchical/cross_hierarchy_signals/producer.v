// Produces a value and a flag that both have to cross two levels to reach the
// top-level outputs.
module producer(input [3:0] din, output [3:0] dout, output flag);
  assign dout = din + 4'd1;
  assign flag = (din == 4'd15);
endmodule
