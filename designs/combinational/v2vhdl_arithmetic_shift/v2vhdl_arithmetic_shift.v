// Arithmetic shifts carried toward VHDL: of a signed and of an unsigned value,
// by a vector count and by a constant, and one nested in an unsigned expression.
//
// numeric_std has no `sra` or `sla` operator. An arithmetic shift of a signed
// value is the function shift_right (shift_left) on a signed, and on an unsigned
// value Verilog's `>>>` is a logical shift, which is shift_right on an unsigned.
// The first version of the hif-backend#94 fix printed the HIF operator name
// instead, `unsigned(a) sra n`, which is not VHDL and which vhdl2hif accepts
// anyway, so the values that came back were right and only the VHDL showed it.
//
// A constant count is its own case: the standardized operand is then resize(s, 32),
// a call with no declaration, and the printer must not ask it for a type.
//
// `nested` is an arithmetic shift inside an unsigned sum. The expression is
// unsigned, so s is converted before it is shifted: a logical shift.
module v2vhdl_arithmetic_shift(
    input  signed [7:0] s,
    input  [7:0] u,
    input  [2:0] n,
    output signed [7:0] sr,
    output signed [7:0] sl,
    output [7:0] ur,
    output signed [7:0] sr1,
    output signed [7:0] sl1,
    output [8:0] nested
);
  assign sr     = s >>> n;
  assign sl     = s <<< n;
  assign ur     = u >>> n;
  assign sr1    = s >>> 1;
  assign sl1    = s <<< 1;
  assign nested = (s >>> n) + u;
endmodule
