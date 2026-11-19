// Chains of shifts of a signed operand, regenerated Verilog to Verilog.
//
// *** THIS DESIGN CURRENTLY FAILS, DELIBERATELY. ***
//
// `(s >>> n) >>> 1` and `(s << 4) >>> 2` come back different on most vectors, on develop as
// well as on the current branch: the shift that is an operand of another shift is cast to the
// width of the integer count and zero-extended, where the whole expression is signed and the
// extension has to be by sign. A cast of a shift is not part-selectable, so the sign
// extension printed for every other operand is not available and the zero-extension fallback
// is used. Needs the shift extended where it is shifted, or the frontend not widening a shift
// to the width of its count at all. Not filed; see the note.
module shift_chain_contexts(
    input  signed [7:0] s,
    input  [2:0] n,
    output signed [7:0] chain,
    output signed [7:0] wide
);
  assign chain = (s >>> n) >>> 1;
  assign wide  = (s << 4) >>> 2;
endmodule
