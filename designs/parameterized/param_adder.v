// Parameterized arithmetic with the carry-out exposed - the intermediate is
// one bit wider than the operands, so the width expression appears twice.
module param_adder #(parameter WIDTH = 8) (
    input [WIDTH-1:0] a,
    input [WIDTH-1:0] b,
    input cin,
    output [WIDTH-1:0] sum,
    output cout
);
  wire [WIDTH:0] wide;
  assign wide = {1'b0, a} + {1'b0, b} + cin;
  assign sum  = wide[WIDTH-1:0];
  assign cout = wide[WIDTH];
endmodule
