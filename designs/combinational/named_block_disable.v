// `disable` on a named block - Verilog-2001's only way to break out of a loop,
// since the language has no `break`. A first-set-bit scan is the canonical use.
//
// *** THIS DESIGN CURRENTLY FAILS, DELIBERATELY. ***
//
// Two defects meet here. hif-backend#85 is the one this design is for:
// hif2verilog drops the named block and its `disable`, so the loop runs to
// completion and the scan reports the *last* set bit instead of the first -
// for d = 8'b1001_0110, seven where the source says one.
//
// It cannot demonstrate that yet, because hif-backend#80 stops the regenerated
// file from parsing first: the same output carries the comma-expression loop
// header for_loop_integer.v covers. So the failure recorded here is at the
// reparse, and the semantic loss sits behind it. When #80 lands this design
// will start failing at a later stage instead, which the runner reports as
// "not the documented failure" - and that is the signal to move the
// declaration to a behavioral pipeline that can see #85 directly.
module named_block_disable(input [7:0] d, output reg [2:0] first_set, output reg found);
  integer i;

  always @(*) begin
    first_set = 3'd0;
    found     = 1'b0;
    begin : scan
      for (i = 0; i < 8; i = i + 1) begin
        if (d[i]) begin
          first_set = i[2:0];
          found     = 1'b1;
          disable scan;
        end
      end
    end
  end
endmodule
