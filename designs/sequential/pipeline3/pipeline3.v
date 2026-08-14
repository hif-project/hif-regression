// Three-stage pipeline. A fault in an early stage takes a predictable number
// of cycles to reach dout, which is what makes this useful behaviorally:
// the effect is separated in time from its cause.
//
// One assignment per register, so each stage is its own unambiguous fault
// location.
module pipeline3(input clk, input rst, input [3:0] din, output reg [3:0] dout);
  reg [3:0] s1;
  reg [3:0] s2;
  always @(posedge clk) begin
    s1   <= rst ? 4'd0 : din;
    s2   <= rst ? 4'd0 : s1;
    dout <= rst ? 4'd0 : s2;
  end
endmodule
