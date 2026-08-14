// Synchronous reset: the reset is sampled on the clock edge like any other
// input, so it does not appear in the sensitivity list.
module dff_sync_reset(input clk, input rst, input d, output reg q);
  always @(posedge clk) begin
    if (rst) q <= 1'b0;
    else     q <= d;
  end
endmodule
