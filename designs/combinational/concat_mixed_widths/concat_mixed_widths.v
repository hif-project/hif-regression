// A concatenation whose operands are all different widths: a scalar, a byte, a
// nibble and a sized literal.
//
// concat_slice.v already joins two vectors, but both of its operands are four
// bits wide, so nothing there depends on the tool getting each operand's
// contribution *right* - a concatenation that mislaid a width would still fill
// the same output. Here the four operands are 1 + 8 + 4 + 3 bits and the
// result is exactly 16, so any width taken wrongly either shifts every field
// or fails to fill the output at all.
//
// `mixed` is the same construct where the operands do not add up to the
// target: 4 + 2 + 1 + 1 is eight bits into eight, but built from a slice of a
// wider signal, which is a different operand kind again.
module concat_mixed_widths(input [7:0] w, input [3:0] n, input s, output [15:0] packed_out, output [7:0] mixed);
  assign packed_out = {s, w, n, 3'b101};
  assign mixed      = {n, w[7:6], s, 1'b0};
endmodule
