// A shifted signed value compared with a negative constant.
//
// *** THIS DESIGN CURRENTLY FAILS, DELIBERATELY. ***
//
// `(s >>> 1) == -1` is true for s = -1 and s = -2, whose arithmetic shift is all ones.
// Regenerated, the shift result is widened and zero-extended before the comparison with the
// 32-bit -1, so it is never equal to it: the design differs exactly on those two inputs (2 of
// 400 random vectors). Develop does the same. The same cause as shift_chain_contexts: a cast
// of a shift is zero-extended, not sign-extended. Tracked as hif-backend#109.
module shift_result_compare(
    input  signed [7:0] s,
    output y
);
  assign y = ((s >>> 1) == -1);
endmodule
