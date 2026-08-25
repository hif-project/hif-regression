// A static `if generate` selecting between two implementations - the main
// reason a design carries a parameter at all.
//
// *** THIS DESIGN CURRENTLY FAILS, DELIBERATELY. ***
//
// hif2verilog prints the generate condition as a bare token sequence in front
// of the `always` keyword, with no `generate`, no `if`, and nothing separating
// them:
//
//   WIDE[0:0]always @( a, b ) begin ...
//   ~ (| WIDE)always @( a, b ) begin ...
//
// Both branches are emitted unconditionally, so even read charitably the
// module now drives `y` from two processes. The output does not parse -
// hif-backend#86. hif2vhdl aborts on the same input, in hif-core's
// standardizeHif.
//
// hif-backend#78 covers the `for generate` half and records `if generate` as
// unaffected. It is not, which is why this design was written.
module if_generate #(parameter WIDE = 1) (input [3:0] a, input [3:0] b, output [4:0] y);
  generate
    if (WIDE) begin : wide_path
      assign y = {1'b0, a} + {1'b0, b};
    end else begin : narrow_path
      assign y = {1'b0, a | b};
    end
  endgenerate
endmodule
