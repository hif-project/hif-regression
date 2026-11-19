// Vectors that run down, but not to bit 0: `[9:2]` is eight bits whose indices are 9 to 2.
//
// *** THIS DESIGN CURRENTLY FAILS, DELIBERATELY. ***
//
// hif2verilog declares such a vector [7:0], whatever its bounds were (getBitwidth), but prints
// every index and part-select with the source's own indices: p[9:6], p[5] against a [7:0]
// declaration, which are out of range and read as x. Develop does the same. Printing any
// constant range as declared, [9:2], and reading the bounds the same way for both directions
// would fix it. Tracked as hif-backend#110.
module descending_offset_vectors(
    input  [9:2] p,
    input  signed [11:4] sp,
    output [3:0] hi,
    output [3:0] lo,
    output signed [11:0] wide,
    output bit5
);
  assign hi   = p[9:6];
  assign lo   = p[5:2];
  assign wide = sp;
  assign bit5 = p[5];
endmodule
