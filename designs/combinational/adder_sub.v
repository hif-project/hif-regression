// Add or subtract under a control bit, with the carry/borrow bit exposed.
// The 5-bit intermediate is what makes the carry observable.
module adder_sub(input [3:0] a, input [3:0] b, input sub, output [3:0] result, output carry);
  wire [4:0] wide;
  assign wide   = sub ? ({1'b0, a} - {1'b0, b}) : ({1'b0, a} + {1'b0, b});
  assign result = wide[3:0];
  assign carry  = wide[4];
endmodule
