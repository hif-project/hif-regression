// Direction under external control, and it wraps in both directions because
// the counter is exactly as wide as its own arithmetic.
module up_down_counter(input clk, input rst, input up, output reg [3:0] count);
  always @(posedge clk) begin
    if (rst)     count <= 4'd0;
    else if (up) count <= count + 1'b1;
    else         count <= count - 1'b1;
  end
endmodule
