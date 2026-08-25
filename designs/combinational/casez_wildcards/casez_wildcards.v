// A priority encoder written with casez - the standard use of the construct,
// and the reason Verilog has it.
//
// *** THIS DESIGN CURRENTLY FAILS, DELIBERATELY. ***
//
// hif2verilog regenerates the `casez` as a plain `case` with the `?` bits
// spelled `z`. Under `case` the comparison is exact, so `4'bzzz1` matches only
// a selector that is literally zzz1: every wildcard alternative becomes
// unreachable and control falls through to the default. hif-backend#84.
//
// The output is valid Verilog, exits 0 and reparses cleanly, which is why this
// design is simulated. Five of the eight stimulus patterns change their
// answer - every one that relied on a wildcard.
module casez_wildcards(input [3:0] req, output reg [1:0] grant, output reg any);
  always @(*) begin
    any = 1'b1;
    casez (req)
      4'b???1: grant = 2'd0;
      4'b??10: grant = 2'd1;
      4'b?100: grant = 2'd2;
      4'b1000: grant = 2'd3;
      default: begin grant = 2'd0; any = 1'b0; end
    endcase
  end
endmodule
