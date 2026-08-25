// Drives the regenerated Verilog and records a CSV trace. There is no VHDL
// simulator here, so the expected trace is computed by hand from the VHDL and
// checked in (expect_regenerated.csv).
//
// The claim is about which end of the vector index 0 names, so the stimulus is
// written as a left-to-right bit pattern and the oracle says `first` is its
// leftmost bit and `last` its rightmost. That statement is independent of how
// the regenerated port ends up declared, which is what makes the design
// survive either fix for #91: printing the port ascending and keeping a[0],
// or keeping it descending and remapping the index to a[3], both put the
// leftmost bit on `first`.
`timescale 1ns/1ps
module vhdl_ascending_range_tb;
  reg [3:0] a;
  wire first, last;
  integer fd;
  reg [4095:0] tracefile;

  vhdl_ascending_range dut (.a(a), .first(first), .last(last));

  task step;
    input [3:0] va;
    begin
      a = va;
      #1 $fdisplay(fd, "%0t,%b,%b,%b", $time, a, first, last);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,a,first,last");

    step(4'b1000);
    step(4'b0001);
    step(4'b1001);
    step(4'b0110);

    $fclose(fd);
    $finish;
  end
endmodule
