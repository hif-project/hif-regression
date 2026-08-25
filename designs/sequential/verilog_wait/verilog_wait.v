// Verilog's level-sensitive `wait (condition)`: it falls through immediately
// when the condition already holds, and suspends only while it does not.
//
// hif-backend#42 emitted the wait's operand instead of the wait statement, so
// the suspension disappeared and the process ran straight on. This is
// specifically the Verilog form, not VHDL's `wait until`, which suspends first
// and tests afterwards - HIF currently represents both the same way
// (hif-core#16), which is precisely why the Verilog reading needs a design that
// states it.
//
// The loop is gated then clocked: while `gate` holds, every rising edge counts.
// The re-entry is the discriminating part - on the iteration after a count,
// `gate` is still high, and a wait that waited for a *change* rather than for
// the *level* would suspend there and stop the counter dead.
`timescale 1ns/1ps

module verilog_wait(input clk, input gate, output reg [3:0] count);

  initial count = 4'd0;

  always begin
    wait (gate);
    @(posedge clk);
    count <= count + 1'b1;
  end
endmodule
