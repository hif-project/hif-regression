// One operand, many contexts. Verilog gives an expression one signedness, signed
// only if every operand is, and every operand is extended to the expression's
// width by that signedness. So the same signed 4-bit t is sign-extended in one
// line and zero-extended in the next, depending on what it is combined with.
//
//   r_lt, r_gt, r_eq  an unsigned a against a signed t: unsigned compare, t is
//                     zero-extended. Operands of a relational operator share a
//                     type; the result is one unsigned bit.
//   mux               n[0] ? a : t - the two arms share a type, unsigned because
//                     a is, so t is zero-extended.
//   nest              s + u + t with an unsigned u: unsigned all the way, so s
//                     and t are zero-extended at both additions.
//   shr_s, shr_t      >> is a logical shift: the shifted operand is not
//                     sign-extended to the width of the shift count.
//   s_lt_t, t_lt_0    all operands signed: a signed compare, so the sign-extended
//                     operand must still be signed when it is compared, or the
//                     comparison reads it as a large positive number.
module signedness_contexts(
    input  [7:0] a,
    input  signed [7:0] s,
    input  signed [3:0] t,
    input  [3:0] u,
    input  [3:0] n,
    output r_lt,
    output r_gt,
    output r_eq,
    output [7:0] mux,
    output [8:0] nest,
    output [7:0] shr_s,
    output [3:0] shr_t,
    output s_lt_t,
    output t_lt_0
);
  assign r_lt   = (a < t);
  assign r_gt   = (t < a);
  assign r_eq   = (a == t);
  assign mux    = n[0] ? a : t;
  assign nest   = s + u + t;
  assign shr_s  = s >> 1;
  assign shr_t  = t >> 1;
  assign s_lt_t = (s < t);
  assign t_lt_0 = (t < 0);
endmodule
