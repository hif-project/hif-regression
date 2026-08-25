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
// The pin is only driven here, never read back. Reading the resolved value of
// an inout the design also drives is a separate path, and a broken one:
// hif2verilog gives the reader a copy of this design's own driver expression
// instead of the net (hif-backend#89). inout_readback.v is that design, and is
// red on that issue - which is where the question belongs, rather than here
// where it would obscure what the Z replication is doing.
module replicated_z_literal(input [3:0] d, input oe, inout [3:0] bus);
  assign bus = oe ? d : {4{1'bz}};
endmodule
