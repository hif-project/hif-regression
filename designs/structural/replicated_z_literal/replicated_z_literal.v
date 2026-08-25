// A tri-state pad whose released state is written as a replication:
// `{4{1'bz}}` rather than `4'bzzzz`.
//
// hif-backend#61 printed a one-bit operand without its size, which turns the
// replication into a concatenation of unsized values. replicated_bit_literal
// covers that for `1'b1`; the four-state literal is a separate value kind in
// the printer, and the Z here has a second job on top of the width: it has to
// stay high-impedance rather than becoming an ordinary 0, 1 or X, which is
// what decides whether this pad ever lets go of the pin.
//
// The testbench is the other device on the bus. That is what makes the design
// prove anything: with nobody else driving, a lowering that drove the pin
// unconditionally would produce exactly this trace. With a second driver, a pad
// that failed to release shows up as contention on the rows where the
// testbench is driving and this design is not.
//
// The pin is only driven here, never read back. A process that reads the
// resolved value of an inout it also drives is a separate path, and one this
// toolchain does not currently get right - it reads back its own driver
// expression instead of the net - so it is deliberately not part of this
// design's question.
module replicated_z_literal(input [3:0] d, input oe, inout [3:0] bus);
  assign bus = oe ? d : {4{1'bz}};
endmodule
