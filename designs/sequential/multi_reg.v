// Several independent registers updated by one process, including one whose
// value is computed rather than merely captured.
module multi_reg(input clk, input rst, input [3:0] a, input [3:0] b,
                 output reg [3:0] ra, output reg [3:0] rb, output reg [3:0] sum);
  always @(posedge clk) begin
    if (rst) begin
      ra  <= 4'd0;
      rb  <= 4'd0;
      sum <= 4'd0;
    end else begin
      ra  <= a;
      rb  <= b;
      sum <= a + b;
    end
  end
endmodule
