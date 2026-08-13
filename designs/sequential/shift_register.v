module shift_register(input clk, input rst, input sin, output reg sout);
  reg [3:0] chain;
  always @(posedge clk) begin
    if (rst) chain <= 4'b0000;
    else     chain <= {chain[2:0], sin};
  end
  assign sout = chain[3];
endmodule
