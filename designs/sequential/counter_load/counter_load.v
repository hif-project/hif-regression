// Parallel load takes priority over increment. Written as one assignment so
// count has a single fault location, making the multi-bit selectors
// unambiguous.
module counter_load(input clk, input rst, input load, input [3:0] din, output reg [3:0] count);
  always @(posedge clk) begin
    count <= rst ? 4'd0 : (load ? din : count + 1'b1);
  end
endmodule
