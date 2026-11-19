// A combinational for loop over a module-level integer - a population count,
// which is the plainest possible use of the construct.
//
// This used to fail, on hif-backend#80: the loop index is shadowed into
// `i_sig_var_0`, and the write-back to `i` was appended to the init and step
// clauses, which regenerated as a comma expression:
//
//   for (i_sig_var_0 = 0, i = i_sig_var_0; i_sig_var_0 < 8;
//        i_sig_var_0 = i_sig_var_0 + 1, i = i_sig_var_0)
//
// Verilog has no comma operator, so neither verilog2hif nor iverilog took it.
// The defect was in verilog2hif, which now publishes `i` once after the loop.
// No generate, no disable, no unusual construct: this is what an ordinary
// iterative combinational function regenerates as.
module for_loop_integer(input [7:0] d, output reg [3:0] cnt);
  integer i;

  always @(*) begin
    cnt = 4'd0;
    for (i = 0; i < 8; i = i + 1) begin
      if (d[i]) cnt = cnt + 4'd1;
    end
  end
endmodule
