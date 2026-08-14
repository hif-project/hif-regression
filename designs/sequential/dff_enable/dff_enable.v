// Clock enable, expressed as a single assignment so that q has exactly one
// fault location - which keeps {signal, bit, type} an unambiguous selector.
// The explicit `q` in the else branch is the hold behavior.
module dff_enable(input clk, input rst, input en, input d, output reg q);
  always @(posedge clk) begin
    q <= rst ? 1'b0 : (en ? d : q);
  end
endmodule
