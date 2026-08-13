module parameterized_default #(parameter [3:0] MAX_VALUE = 4'hF) (input clk, input rst, output reg [3:0] value);
  always @(posedge clk) begin
    if (rst) value <= 4'b0000;
    else if (value == MAX_VALUE) value <= 4'b0000;
    else value <= value + 1'b1;
  end
endmodule
