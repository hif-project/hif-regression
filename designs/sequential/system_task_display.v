// A Verilog system *task* call - $display - alongside the RTL it reports on.
//
// hif-backend#29 did not emit system task calls at all. That is a different
// path from a system function: $clog2 returns a value into an expression and
// param_clog2.v covers it, while $display is a statement with no result, and
// the printer reaches it as a procedure call rather than as an operand.
//
// The call is inside the clocked process rather than in a process of its own,
// so it has to survive as one statement among others - a printer that emitted
// the process but skipped the statements it did not recognise would still
// produce a working register and lose only the call.
//
// Round-trip only. What $display does is write to the simulator's transcript,
// which is not an artifact this corpus compares; the claim here is that the
// call is still there and still reparses.
module system_task_display(input clk, input [3:0] d, output reg [3:0] q);
  always @(posedge clk) begin
    q <= d;
    $display("captured %0d", d);
  end
endmodule
