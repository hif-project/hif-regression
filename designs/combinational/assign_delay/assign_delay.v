// A delayed continuous assignment: the one construct in this corpus whose
// correctness is a question about *when*, not *what*.
//
// hif-backend#24 dropped the delay entirely. `verilog2hif` recorded it, and
// hif2verilog's assignment printer never read it, so the regenerated design
// responded immediately where this one waits. Nothing short of simulating with
// timing could see it: the regenerated Verilog parsed, reparsed and produced
// the same steady-state values.
//
// `y` reads the delayed net and `c`, which does not go through it. That second
// path is what distinguishes a delay that was preserved from one applied too
// broadly - a regenerated design that suspends the whole process instead of
// scheduling just `t` also holds `y` back from `c`, and gets the steady state
// right while getting the timing wrong in the other direction.
`timescale 1ns / 1ps

module assign_delay(input a, input b, input c, output y, output z);
  wire t;

  assign #2 t = a & b;
  assign y = t ^ c;
  assign z = t | b;
endmodule
