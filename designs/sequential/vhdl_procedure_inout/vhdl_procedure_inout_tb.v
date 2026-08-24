// Drives the regenerated Verilog and records a CSV trace.
//
// There is no VHDL simulator here, so this never runs against the design's own
// source - only against the Verilog hif2verilog regenerates from it. The
// expected trace is computed by hand from the VHDL and checked in.
//
// Sampled just before each rising edge, so every row is the state the previous
// edge established and the divide-by-two is visible as an alternating column
// rather than as a race against the edge itself.
//
// The `inout` failure this guards is non-convergence, not lateness: with the
// copy-in overwriting the pending value on every call, q stays x for as long as
// the clock runs. Eight edges is well past the point where a merely-late
// implementation would have settled, which is what distinguishes the two.
`timescale 1ns/1ps
module vhdl_procedure_inout_tb;
  reg clk, rst;
  wire q;
  integer i;
  integer fd;
  reg [4095:0] tracefile;

  vhdl_procedure_inout dut (.clk(clk), .rst(rst), .q(q));

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,rst,q");

    clk = 1'b0;
    rst = 1'b1;

    // Two reset edges, so the starting state is established rather than assumed.
    for (i = 0; i < 2; i = i + 1) begin
      #5 clk = 1'b1;
      #5 clk = 1'b0;
      $fdisplay(fd, "%0t,%b,%b", $time, rst, q);
    end

    rst = 1'b0;

    // Eight free-running edges: q must alternate on every one of them.
    for (i = 0; i < 8; i = i + 1) begin
      #5 clk = 1'b1;
      #5 clk = 1'b0;
      $fdisplay(fd, "%0t,%b,%b", $time, rst, q);
    end

    $fclose(fd);
    $finish;
  end
endmodule
