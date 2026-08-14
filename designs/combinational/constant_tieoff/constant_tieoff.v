// Constant tie-offs on outputs: unused status bits, fixed ID fields, stubbed
// interfaces. Ordinary RTL, and until hif-backend#30 the toolchain lost all of
// it.
//
// verilog2hif folds a constant continuous assignment into the value of the
// port it drives, for any constant right-hand side. hif2verilog printed that
// value nowhere - Verilog-2001 has no place for an initializer inside an ANSI
// port list - so every output here regenerated with no driver at all and read
// x. Exit 0, and the output compiled and reparsed cleanly either way.
//
// Every output is driven by nothing but a constant continuous assignment,
// which is the point: there is no other driver to mask the loss.
module constant_tieoff #(parameter N = 4) (
    input  wire       en,
    output [31:0] id,
    output [7:0]  mask,
    output        ready,
    output [3:0]  gated
);

  // A plain sized constant.
  assign id    = 32'd7;
  // A replication whose count is a parameter, so the folded value is an
  // expression rather than a literal.
  assign mask  = {N{1'b1}};
  // The one-bit shape a stubbed status flag takes.
  assign ready = 1'b1;
  // Not a constant, so verilog2hif does NOT fold this one - it stays a real
  // continuous assignment. Present so the design still has a driver that
  // travels the ordinary path, and so the trace moves rather than sitting at
  // one value.
  assign gated = en ? 4'b1010 : 4'b0101;

endmodule
