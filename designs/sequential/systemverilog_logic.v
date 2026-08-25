// SystemVerilog `logic` used the way RTL normally uses it: as an ordinary
// four-state variable, both held across a clock edge and written by a blocking
// assignment.
//
// `logic` is not a lexer keyword in verilog2hif - it arrives at the
// post-parsing refinements as an unresolved type name and used to be renamed
// unconditionally to the Verilog-AMS `logic` discipline. For a design that
// does not pull in the AMS disciplines library that exchanged one unresolved
// name for another, and the first pass needing the base type aborted the tool
// (hif-frontend#21). The second half of that fix is what the two declarations
// below are for: a discipline net does not get variable semantics, and only a
// variable can be a procedural assignment target at all.
//
// Ports stay untyped. `input logic d` inside an ANSI port header is a separate,
// still-unsupported spelling, and mixing it in here would stop this design from
// reaching the declaration path it is about.
//
// Round-trip rather than behavioral: the remaining half of #21 is the default
// value a `logic` declaration starts from - 'X' for a variable against 'Z' for
// a net - and X and Z are indistinguishable through every operator this design
// could plausibly use, so simulating it would not add a claim.
module systemverilog_logic(input clk, input en, input [3:0] d, output [3:0] q, output parity);
  logic [3:0] value;
  logic       odd;

  always @(posedge clk) begin
    if (en) value <= d;
  end

  always @(*) begin
    odd = ^value;
  end

  assign q      = value;
  assign parity = odd;
endmodule
