// Two devices sharing a bus, each releasing it when not selected - a net with
// two continuous drivers, resolved by the simulator.
//
// This used to fail, on hif-backend#88: the net was regenerated as a single
// `output reg` written by two `always` blocks. A reg has no resolution: the last
// process to run wins, so whichever driver happened to be evaluated second
// overwrote the other with its own released value, and a bus driven by exactly one
// device read zzzz. Valid Verilog, exit 0, reparsed cleanly.
//
// The cause was in verilog2hif, which lowered every continuous assign to a process.
// It now keeps the continuous assigns of a net that two of them provably drive, and
// hif2verilog prints them as the two `assign` lines of the source.
//
// replicated_z_literal covers a single driver releasing a pin. This is two, and the
// VHDL-sourced equivalent, vhdl_shared_bus, already passed.
module multiple_wire_drivers(input a_en, input [3:0] a, input b_en, input [3:0] b, output [3:0] bus);
  assign bus = a_en ? a : 4'bzzzz;
  assign bus = b_en ? b : 4'bzzzz;
endmodule
