// A saturating accumulator, with the update factored into a task.
//
// The task takes all three argument directions, and each is the natural choice
// for what it carries: the running total is read and written so it is `inout`,
// the increment is `input`, the saturation flag is `output`. It is written with
// an ANSI-style header - `task add_sat(inout [3:0] total, ...)` - which is how
// Verilog-2001 code is normally written.
//
// It is here because of hif-frontend#25. verilog2hif refused *both* of those
// spellings outright, with a bare yyerror and exit 134:
//
//   task t; inout s; ... endtask     the non-ANSI inout declaration
//   task t(input v);  ... endtask    every ANSI header, for every direction
//
// So the corpus could not contain a task with a non-`in` argument at all, in
// either spelling, and had none. This is the ordinary shape of Verilog that
// uses a task for anything other than a pure computation.
//
// The task also declares a local, which is a separate path in the ANSI form:
// the body's declarations arrive at the parser separately from the arguments
// there, where the non-ANSI form interleaves them.
//
// *** THIS DESIGN CURRENTLY FAILS, DELIBERATELY. ***
//
// It fails on hif-frontend#31, which it is what found: the reset branch assigns
// acc_r directly and the other branch writes it through the task's inout
// argument, and that mix makes refineToVariables shadow acc_r into a _sig_var
// variable. The shadow is written back to the signal after the direct
// assignment and *not* after the task call, so acc_r stops updating and the
// accumulator reads 0 for the whole run where its own source reads 3, 6, 9,
// 12, 15.
//
// The design is left in this shape on purpose. A saturating accumulator with a
// synchronous reset is ordinary RTL, the mix that triggers the bug is the
// natural way to write it, and #31 is a real defect - silent, exit 0, output
// that compiles and reparses. Rewriting the design to route around it (by
// folding the reset into the task, say) would make the corpus green by making
// it stop asking the question, which is the opposite of what a corpus is for.
//
// This design goes green when #31 is fixed. Nothing else about it should
// change at that point.
module verilog_task_arguments (
    input            clk,
    input            rst,
    input      [3:0] delta,
    output     [3:0] acc,
    output           sat
);

    reg [3:0] acc_r;
    reg       sat_r;

    // inout: read to compute the sum, written back with the result.
    task add_sat(inout [3:0] total, input [3:0] d, output ovf);
        reg [4:0] wide;
        begin
            wide = {1'b0, total} + {1'b0, d};
            if (wide[4]) begin
                total = 4'hF;
                ovf   = 1'b1;
            end else begin
                total = wide[3:0];
                ovf   = 1'b0;
            end
        end
    endtask

    // Blocking throughout: a task's arguments are copied back on return, so
    // mixing the two assignment kinds on the same register here would be a
    // race the source does not intend.
    always @(posedge clk) begin
        if (rst) begin
            acc_r = 4'h0;
            sat_r = 1'b0;
        end else begin
            add_sat(acc_r, delta, sat_r);
        end
    end

    assign acc = acc_r;
    assign sat = sat_r;

endmodule
