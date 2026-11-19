// Verilog evaluates an expression as unsigned as soon as any operand is, and
// extends every operand the same way. So `a + b` with an unsigned `a` and a
// signed `b` zero-extends `b` too: with a = 36 and b = -127 (8'b1000_0001) the
// sum is 36 + 129 = 165, not 36 - 127 = -91.
//
// hif2verilog used to sign-extend any signed source it widened, which is right
// for the second output - both operands are signed there, so the extension is
// by sign - and wrong for the first. It extends by sign only when every operand
// of the expression is signed. This design has both on purpose: they are
// opposite answers for the same signed operand `b`, and a printer that gets one
// right by always doing the same thing gets the other wrong.
module mixed_signedness_add(
    input  [7:0] a,
    input  signed [7:0] b,
    input  signed [7:0] c,
    output [8:0] mixed,
    output signed [8:0] both_signed
);
  assign mixed       = a + b;
  assign both_signed = b + c;
endmodule
