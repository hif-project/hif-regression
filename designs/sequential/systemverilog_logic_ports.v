// SystemVerilog `logic` in an ANSI port header - the normal style for a
// SystemVerilog design, and the position systemverilog_logic.v deliberately
// avoids.
//
// *** THIS DESIGN CURRENTLY FAILS, DELIBERATELY. ***
//
// verilog2hif parses a port's type as a Verilog-AMS discipline, and `logic` is
// not a lexer keyword, so it arrives as an identifier the discipline rule does
// not accept:
//
//   ERROR: discipline_and_modifiers: IDENTIFIER is not supported
//
// and the tool aborts - hif-frontend#33. In a body declaration the same
// keyword works, which hif-frontend#21 established and systemverilog_logic.v
// covers. That fixture keeps its ports untyped for exactly this reason, which
// left the port form unasked; this design asks it.
module systemverilog_logic_ports (input logic clk, input logic [3:0] d, output logic [3:0] q);
  always @(posedge clk) q <= d;
endmodule
