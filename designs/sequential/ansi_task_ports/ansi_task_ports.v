// A task declared with an ANSI-style header carrying all three argument
// directions - `task advance(inout [3:0] p, input [3:0] d, input clear, output
// ovf);` - which is how Verilog-2001 code is normally written.
//
// verilog2hif used to refuse this outright, with a bare yyerror and exit 134:
// every ANSI task header, for every direction, and the non-ANSI `inout`
// declaration too (hif-frontend#25). The corpus had no task with a non-`in`
// argument in either spelling.
//
// This design is the *passing* half of that coverage, and it is what marks
// where hif-frontend#31 actually begins. verilog_task_arguments carries the
// same ANSI header and fails, because its accumulator is written directly in
// the reset branch and through the task's inout argument in the other; that
// mix is what makes refineToVariables shadow the register and drop the
// write-back after the call. Here the reset is a task argument too, so `pos`
// is written through the call and nowhere else - and the accumulator counts.
//
// Keeping both is the point. If one day #31 is "fixed" by suppressing the
// shadow entirely, this design is what says the ordinary case still works.
module ansi_task_ports(input clk, input rst, input [3:0] step, output reg [3:0] pos, output reg wrapped);

  // The running total is read and written, so it is `inout`; the increment and
  // the clear are `input`; the carry out of four bits is `output`.
  task advance(inout [3:0] p, input [3:0] d, input clear, output ovf);
    reg [4:0] wide;
    begin
      if (clear) begin
        p   = 4'd0;
        ovf = 1'b0;
      end else begin
        wide = {1'b0, p} + {1'b0, d};
        p    = wide[3:0];
        ovf  = wide[4];
      end
    end
  endtask

  // Blocking, because a task's arguments are copied back on return: mixing the
  // two assignment kinds on this register would be a race the source does not
  // intend.
  always @(posedge clk) begin
    advance(pos, step, rst, wrapped);
  end
endmodule
