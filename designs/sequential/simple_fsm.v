module simple_fsm(input clk, input rst, input go, output reg done);
  localparam IDLE = 2'b00, RUN = 2'b01, DONE = 2'b10;
  reg [1:0] state;
  always @(posedge clk) begin
    if (rst) begin
      state <= IDLE;
      done  <= 1'b0;
    end else begin
      case (state)
        IDLE: if (go) state <= RUN;
        RUN:  begin state <= DONE; done <= 1'b1; end
        DONE: state <= IDLE;
        default: state <= IDLE;
      endcase
    end
  end
endmodule
