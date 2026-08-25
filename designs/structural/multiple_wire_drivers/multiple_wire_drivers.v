// Two devices sharing a bus, each releasing it when not selected - a net with
// two continuous drivers, resolved by the simulator.
//
// *** THIS DESIGN CURRENTLY FAILS, DELIBERATELY. ***
//
// hif2verilog regenerates the net as a single `output reg` written by two
// `always` blocks. A reg has no resolution: the last process to run wins, so
// whichever driver happens to be evaluated second overwrites the other with
// its own released value. hif-backend#88.
//
// The result is that a bus driven by exactly one device reads zzzz - the
// asserting driver is overwritten by the released one. Valid Verilog, exit 0,
// reparses cleanly.
//
// replicated_z_literal covers a single driver releasing a pin, and passes.
// This is what happens when there are two, and the VHDL-sourced equivalent -
// vhdl_shared_bus - already passes, so the gap is specific to the Verilog path.
module multiple_wire_drivers(input a_en, input [3:0] a, input b_en, input [3:0] b, output [3:0] bus);
  assign bus = a_en ? a : 4'bzzzz;
  assign bus = b_en ? b : 4'bzzzz;
endmodule
