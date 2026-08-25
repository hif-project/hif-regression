// `repeat (N) @(posedge clk)` - a repeat count around an event control, which
// is how a fixed number of clock periods is written when there is no counter to
// spare.
//
// HIF has no repeat: hif2verilog lowers it to a for loop over a synthetic index
// it has to declare and initialise itself, which is what hif-backend#47 did not
// do. A loop whose index starts wherever the last one left it is still a legal
// loop; it just runs the wrong number of times, and here that means the pulse
// arrives on the wrong clock.
//
// The pulse is one clock wide and repeats every fourth clock - three edges
// consumed by the repeat, one by the release - so the period in the trace *is*
// the repeat count. `pulses` accumulates so a period that drifted rather than
// changed outright still separates from a correct run.
`timescale 1ns/1ps

module repeat_event(input clk, output reg pulse, output reg [3:0] pulses);

  initial begin
    pulse  = 1'b0;
    pulses = 4'd0;
  end

  always begin
    repeat (3) @(posedge clk);
    pulse  <= 1'b1;
    pulses <= pulses + 1'b1;
    @(posedge clk);
    pulse  <= 1'b0;
  end
endmodule
