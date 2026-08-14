// Parameterized-width shift register, three stages deep.
//
// The stages are separate registers rather than slices of one wide register.
// A parameterized part-select such as chain[WIDTH*DEPTH-1:WIDTH*(DEPTH-1)]
// currently regenerates as malformed Verilog - see
// https://github.com/hif-project/hif-backend/issues/18.
module param_shift #(parameter WIDTH = 4) (
    input clk,
    input rst,
    input [WIDTH-1:0] din,
    output reg [WIDTH-1:0] dout
);
  reg [WIDTH-1:0] s1;
  reg [WIDTH-1:0] s2;
  always @(posedge clk) begin
    if (rst) begin
      s1   <= {WIDTH{1'b0}};
      s2   <= {WIDTH{1'b0}};
      dout <= {WIDTH{1'b0}};
    end else begin
      s1   <= din;
      s2   <= s1;
      dout <= s2;
    end
  end
endmodule
