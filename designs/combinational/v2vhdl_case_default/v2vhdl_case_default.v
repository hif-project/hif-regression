// A Verilog case with a `default` carried toward VHDL. No open issue -
// regression protection for a mapping that currently works.
//
// VHDL requires a case statement's choices to be exhaustive, so `default` has
// to become `WHEN OTHERS`; emitted as an explicit `WHEN "11"` it would cover
// the one selector value the named alternatives miss while leaving the
// metavalues uncovered, and dropped entirely it would leave the statement
// non-exhaustive.
//
// This is the mirror of combinational/vhdl_case, which asks the same question
// in the other direction - whether VHDL's mandatory `others` comes out as
// Verilog's `default`. The two are different mappings, not one: VHDL always has
// an others to translate, whereas a Verilog case need not have a default at
// all, so the backend has to synthesise exhaustiveness rather than preserve it.
//
// Every alternative computes something different from every other, so a
// selector routed to the wrong branch is a wrong value rather than a
// coincidence.
module v2vhdl_case_default(
    input  [1:0] s,
    input  [3:0] a,
    input  [3:0] b,
    output reg [3:0] y
);
  always @(*) begin
    case (s)
      2'b00: y = a;
      2'b01: y = b;
      2'b10: y = a & b;
      default: y = a ^ b;
    endcase
  end
endmodule
