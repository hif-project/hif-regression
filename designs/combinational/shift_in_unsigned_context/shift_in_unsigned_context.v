// A shift inside a larger expression. The shift count is self-determined, but the
// shifted operand is not: it takes its signedness from the whole expression it is
// part of. `(s >>> n) + a` has an unsigned a, so the expression is unsigned and s
// is converted to unsigned BEFORE it is shifted: a logical shift, although `>>>`
// and a signed s. A bare `s >>> n` is arithmetic.
//
// Typing a shift by its first operand alone, which the bare case needs since the
// count must not make it unsigned, made both arithmetic, and the first one wrong.
module shift_in_unsigned_context(
    input  signed [7:0] s,
    input  [7:0] a,
    input  [2:0] n,
    output [8:0] unsigned_ctx,
    output [7:0] bare
);
  assign unsigned_ctx = (s >>> n) + a;
  assign bare         = s >>> n;
endmodule
