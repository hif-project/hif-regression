// A three-state machine exposing both output styles from the same state:
// `moore` depends only on the current state, `mealy` also depends on the
// input. A fault on state therefore reaches the two outputs differently,
// which is the state/output interaction this fixture is here to exercise.
//
// The next-state logic is one conditional expression, so state has a single
// fault location.
module fsm_moore_mealy(input clk, input rst, input go,
                       output reg [1:0] state, output moore, output mealy);
  localparam IDLE = 2'd0, RUN = 2'd1, DONE = 2'd2;

  always @(posedge clk) begin
    state <= rst                ? IDLE :
             (state == IDLE)    ? (go ? RUN : IDLE) :
             (state == RUN)     ? DONE :
                                  IDLE;
  end

  assign moore = (state == DONE);
  assign mealy = (state == RUN) & go;
endmodule
