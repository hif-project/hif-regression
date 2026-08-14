// Outermost level. top -> middle -> leaf.
module top(input a, input b, input c, input d, output y);
  wire mid_out;
  middle u_middle(.a(a), .b(b), .c(c), .y(mid_out));
  assign y = mid_out ^ d;
endmodule
