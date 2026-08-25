// A genuine Verilog `initial` block: a power-on reset asserted at time zero and
// released exactly once.
//
// hif-backend#40 emitted a run-once process as `always` rather than `initial`.
// The difference is invisible in the steady state and invisible to a reparse -
// both spellings are legal Verilog around the same body - but it changes what
// the design does. Replayed as an `always`, this body re-enters immediately
// after its last statement, so `rst_n` returns to 0 in the same instant it
// reached 1 and is never high for any measurable time: the counter below stays
// at zero for the whole run instead of counting.
//
// The release is at 12 ns, deliberately not on a clock edge, so the trace
// records the one-shot release and not a race between the initial block and the
// clocked process.
`timescale 1ns/1ps

module initial_block(input clk, output reg rst_n, output reg [3:0] count);

  // Runs once. Nothing else in the design drives rst_n, so the counter's
  // ability to leave zero is exactly the claim that this ran once and stopped.
  initial begin
    rst_n = 1'b0;
    #12 rst_n = 1'b1;
  end

  always @(posedge clk) begin
    if (!rst_n) count <= 4'd0;
    else        count <= count + 1'b1;
  end
endmodule
