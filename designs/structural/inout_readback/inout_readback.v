// A bidirectional pad that drives the pin when enabled and senses it
// otherwise - which is the entire purpose of a bidirectional pad.
//
// *** THIS DESIGN CURRENTLY FAILS, DELIBERATELY. ***
//
// hif2verilog gives the reader a copy of this design's own driver expression
// instead of the resolved value of the net. The process implementing
// `assign sensed = bus` never mentions `bus`: it recomputes `oe ? d : 4'bzzzz`
// and reads that, and its sensitivity list is `d, oe`, so it cannot see the
// pin change at all. hif-backend#89.
//
// The design still works whenever it is the only driver, which is why this
// hides until a second device appears - and why the testbench is that second
// device. With the testbench driving and this design released, `sensed` reads
// zzzz where it should read the testbench's value.
//
// replicated_z_literal drives the pin and never reads it back, for exactly
// this reason. This design is the read-back that omission left unasked.
module inout_readback(input [3:0] d, input oe, inout [3:0] bus, output [3:0] sensed);
  assign bus    = oe ? d : 4'bzzzz;
  assign sensed = bus;
endmodule
