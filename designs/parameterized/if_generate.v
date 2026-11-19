// A static `if generate` selecting between two implementations - the main
// reason a design carries a parameter at all.
//
// This used to fail, on hif-backend#86: hif2verilog printed the generate
// condition as a bare token sequence in front of the `always` keyword, with no
// `generate`, no `if`, and nothing separating them:
//
//   WIDE[0:0]always @( a, b ) begin ...
//   ~ (| WIDE)always @( a, b ) begin ...
//
// Both branches were emitted unconditionally, so even read charitably the
// module drove `y` from two processes. The output did not parse. hif2verilog
// now prints each branch as `generate if (cond) begin : name ... end
// endgenerate`. hif2vhdl still aborts on the same input, in hif-core's
// standardizeHif - the other half of #86, not covered by this pipeline.
//
// hif-backend#78 covers the `for generate` half and recorded `if generate` as
// unaffected. It was not, which is why this design was written.
module if_generate #(parameter WIDE = 1) (input [3:0] a, input [3:0] b, output [4:0] y);
  generate
    if (WIDE) begin : wide_path
      assign y = {1'b0, a} + {1'b0, b};
    end else begin : narrow_path
      assign y = {1'b0, a | b};
    end
  endgenerate
endmodule
