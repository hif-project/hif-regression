// `disable` on a named block - Verilog-2001's only way to break out of a loop,
// since the language has no `break`. A first-set-bit scan is the canonical use.
//
// Two things made this fail before it could say so. hif-backend#80 stopped the
// regenerated file from parsing at all, and behind it hif-backend#85 dropped the
// named block and its `disable`, so the loop ran to completion and the scan
// reported the *last* set bit instead of the first - for d = 8'b1001_0110, seven
// where the source says one. Both are fixed. The behavioral comparison is what
// sees #85: the regenerated file is valid and reparses cleanly.
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
