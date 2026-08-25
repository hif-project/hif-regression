// An ordinary user-defined Verilog task: the classic non-ANSI declaration, two
// input arguments, two output arguments, and one call from a clocked process.
//
// hif-backend#38 did not emit a user-defined task as a task at all.
// hif-backend#64 emitted the task but not the declarations for its out
// arguments. hif-backend#70 then assigned an out argument with `<=` instead of
// `=`: a task's outputs are copied back to the actuals when the task returns,
// so scheduling the write instead of performing it makes the copy-back read the
// argument's previous value - valid Verilog that reports last cycle's answer.
// That last one is why this design is simulated rather than merely reparsed.
//
// Deliberately separate from verilog_task_arguments, which is the ANSI header
// with an `inout`: this is the plain form, every argument is `input` or
// `output`, and both actuals are written only through the call - never also
// assigned directly - so the mix that hif-frontend#31 turns on is not in play
// here.
module user_task(input clk, input [3:0] a, input [3:0] b, output reg [3:0] upper, output reg [3:0] lower);

  // Order two values. Both outputs are written on both paths, so a copy-back
  // that publishes stale values shows up as the previous cycle's ordering
  // rather than as a held or unknown output.
  task sort2;
    input [3:0] x;
    input [3:0] z;
    output [3:0] hi;
    output [3:0] lo;
    begin
      if (x >= z) begin
        hi = x;
        lo = z;
      end else begin
        hi = z;
        lo = x;
      end
    end
  endtask

  always @(posedge clk) begin
    sort2(a, b, upper, lower);
  end
endmodule
