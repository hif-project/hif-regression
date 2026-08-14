// A chain of continuous assignments through named intermediate wires, at
// increasing expression depth - each stage is its own fault location.
module continuous_assigns(input [3:0] a, input [3:0] b, output [3:0] y);
  wire [3:0] level1;
  wire [3:0] level2;
  wire [3:0] level3;

  assign level1 = a & b;
  assign level2 = level1 | (a ^ b);
  assign level3 = ~level2;
  assign y      = level3 & (a | b);
endmodule
