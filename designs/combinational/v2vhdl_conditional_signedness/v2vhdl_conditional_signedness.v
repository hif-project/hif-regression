// An unsigned arm and a signed arm of a conditional, carried toward VHDL.
//
// *** THIS DESIGN CURRENTLY FAILS, DELIBERATELY. ***
//
// The arms of `n[0] ? a : t` share one type, unsigned because a is, so Verilog zero-extends
// the signed 4-bit t to 8 bits. The HIF says that as a cast of t to an unsigned 8-bit type,
// and hif-core's VHDLCastAnalysis::_mapVectors lowers that cast as resize(t, 8) on the
// signed t, which sign-extends in VHDL: t = -1 comes back as 8'hFF where the source says
// 8'h0F. Develop hid it only because it dropped `signed` from the port, so the resize was on
// an unsigned. Making the cast zero-extend for an unsigned target fixes this and breaks
// `-(s >>> 1)` and `{(t >>> 1), u}`, where the frontend casts a signed operand to an
// unsigned type and relies on the sign extension, so the real fix is the frontend typing
// the cast by the context of the whole expression. Not filed; see the note.
module v2vhdl_conditional_signedness(
    input  [7:0] a,
    input  signed [3:0] t,
    input  [2:0] n,
    output [7:0] y
);
  assign y = n[0] ? a : t;
endmodule
