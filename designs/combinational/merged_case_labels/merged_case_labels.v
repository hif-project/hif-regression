// A case statement with two alternatives that do the same thing, written out
// separately.
//
// They are written separately on purpose. HIF keeps one alternative per body,
// so the frontend folds these two into a single alternative carrying two
// conditions, and the merged form is something the toolchain built rather than
// something copied out of the source. Regenerating it needs the labels
// comma-separated, which hif-backend#68 did not do: the two constants ran
// together into one token.
//
// Every value of `sel` has an alternative, so the process is combinational
// with no implicit hold. A label lost in the merge would leave `sel = 2'b01`
// with nothing to match, and `y` would keep its previous value - still valid
// Verilog, and a latch where the source has none.
module merged_case_labels(input [1:0] sel, input [3:0] a, input [3:0] b, output reg [3:0] y);
  always @(*) begin
    case (sel)
      2'b00: y = a;
      2'b01: y = a;
      2'b10: y = b;
      2'b11: y = ~b;
    endcase
  end
endmodule
