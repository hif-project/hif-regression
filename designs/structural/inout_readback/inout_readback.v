// A bidirectional pad that drives the pin when enabled and senses it
// otherwise - which is the entire purpose of a bidirectional pad.
//
// This used to fail, on hif-backend#89: the reader was given a copy of this design's
// own driver expression instead of the resolved value of the net. The process
// implementing `assign sensed = bus` never mentioned `bus`: it recomputed
// `oe ? d : 4'bzzzz` and read that, and its sensitivity list was `d, oe`, so it could
// not see the pin change at all. verilog2hif now keeps the continuous assign of an
// output or inout port that is read, so `sensed` reads the port.
//
// The design still worked whenever it was the only driver, which is why this hid until
// a second device appeared - and why the testbench is that second device. With the
// testbench driving and this design released, `sensed` read zzzz where it should read
// the testbench's value.
//
// replicated_z_literal drives the pin and never reads it back, for exactly this
// reason. This design is the read-back that omission left unasked.
module inout_readback(input [3:0] d, input oe, inout [3:0] bus, output [3:0] sensed);
  assign bus    = oe ? d : 4'bzzzz;
  assign sensed = bus;
endmodule
