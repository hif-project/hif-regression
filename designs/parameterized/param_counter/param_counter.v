// Parameterized-width counter, written as a single assignment so count has
// exactly one fault location and {signal, bit, type} stays unambiguous.
module param_counter #(parameter WIDTH = 4) (
    input clk,
    input rst,
    input en,
    output reg [WIDTH-1:0] count
);
  always @(posedge clk) begin
    count <= rst ? {WIDTH{1'b0}} : (en ? count + 1'b1 : count);
  end
endmodule
