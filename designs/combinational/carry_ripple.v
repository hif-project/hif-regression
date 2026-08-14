// Explicit carry chain: each intermediate carry is its own wire rather than
// being hidden inside one wide addition, so a fault on any single carry is
// independently observable.
//
// The sum bits are gathered into one assignment rather than written as
// `assign sum[0] = ...`: a bit-select on the left of a continuous assign
// currently crashes hif2verilog - see
// https://github.com/hif-project/hif-backend/issues/17. The carry chain, which
// is the point of this fixture, is unaffected.
module carry_ripple(input [3:0] a, input [3:0] b, input cin, output [3:0] sum, output cout);
  wire c1, c2, c3;
  wire s0, s1, s2, s3;

  assign s0 = a[0] ^ b[0] ^ cin;
  assign c1 = (a[0] & b[0]) | (cin & (a[0] ^ b[0]));

  assign s1 = a[1] ^ b[1] ^ c1;
  assign c2 = (a[1] & b[1]) | (c1 & (a[1] ^ b[1]));

  assign s2 = a[2] ^ b[2] ^ c2;
  assign c3 = (a[2] & b[2]) | (c2 & (a[2] ^ b[2]));

  assign s3 = a[3] ^ b[3] ^ c3;

  assign sum  = {s3, s2, s1, s0};
  assign cout = (a[3] & b[3]) | (c3 & (a[3] ^ b[3]));
endmodule
