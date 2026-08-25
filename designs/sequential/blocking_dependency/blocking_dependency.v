// Two blocking assignments in one process where the second reads what the
// first just wrote.
//
// This is the semantics a blocking assignment exists for: `b` sees the new `a`,
// not the one from the previous edge. Turn either statement into a
// non-blocking assignment and the process still has two statements, still
// writes both registers on every edge, and still reparses - `b` is simply one
// cycle behind, which is exactly the pipeline the source is not.
//
// The corpus's other clocked processes are all non-blocking: pipeline3 is
// three stages that deliberately *do* read the previous value, multi_reg
// writes independent registers. Neither states what a blocking assignment
// makes visible within one process.
//
// `b` is `a` plus one rather than a copy of it, so a `b` that lagged by a
// cycle is a different number and not merely the same number arriving late.
module blocking_dependency(input clk, input [3:0] d, output reg [3:0] a, output reg [3:0] b);
  always @(posedge clk) begin
    a = d + 4'd1;
    b = a + 4'd1;
  end
endmodule
