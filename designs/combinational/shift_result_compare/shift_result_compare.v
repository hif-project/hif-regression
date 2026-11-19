// A shifted signed value compared with a negative constant.
//
// *** THIS DESIGN CURRENTLY FAILS, DELIBERATELY. ***
//
// `(s >>> 1) == -1` is true for a negative s, whose arithmetic shift is all ones or ends in
// one. Regenerated, the shift result is widened and zero-extended before the comparison with
// the 32-bit -1, so it is never equal to it except by accident, and 2 of 400 random vectors
// still agree. Develop does the same. The same cause as shift_chain_contexts: a cast of a
// shift is zero-extended, not sign-extended. Not filed; see the note.
module shift_result_compare(
    input  signed [7:0] s,
    output y
);
  assign y = ((s >>> 1) == -1);
endmodule
