// Replication of a one-bit operand: `{4{1'b1}}` as a whole value, as one
// element of a wider concatenation, and over a signal rather than a literal.
//
// hif-backend#61 printed a one-bit value without its size. The result is still
// a concatenation and still reparses - verilog2hif accepts an operand of
// indefinite width - but no simulator will elaborate it, because a
// concatenation operand has to have a width. That asymmetry is why this design
// is simulated: the round trip alone cannot tell `{1'b1, 1'b1}` from `{1, 1}`.
//
// `mask` and `wide` are constant. They were checked by hand when this fixture
// was added: the regenerated file still spells them as nested concatenations
// of sized literals rather than folding them to 4'b1111 and 8'b00001111, so
// the replication really is on the path. The pipeline cannot assert that, so
// `y` replicates a signal instead - the same construct where folding is not
// available at all, and the trace has to carry it.
//
// Distinct from param_bitmask, whose replication count is a parameter
// expression and whose pipeline stops at the reparse: the count here is a
// plain literal and the claim is about the operand's width.
module replicated_bit_literal(input [3:0] d, input sel, output [3:0] mask, output [3:0] y, output [7:0] wide);
  assign mask = {4{1'b1}};
  assign y    = d & {4{sel}};
  assign wide = {{4{1'b0}}, {4{1'b1}}};
endmodule
