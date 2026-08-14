// The simplest possible sequential element - no reset, no enable.
module dff(input clk, input d, output reg q);
  always @(posedge clk) begin
    q <= d;
  end
endmodule
