// Feedback shift register: the next state depends on the current state rather
// than on any input, so a fault perturbs the whole subsequent sequence rather
// than a single cycle.
module shift_lfsr(input clk, input rst, output reg [3:0] lfsr);
  always @(posedge clk) begin
    if (rst) lfsr <= 4'b0001;
    else     lfsr <= {lfsr[2:0], lfsr[3] ^ lfsr[2]};
  end
endmodule
