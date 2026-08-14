// Drives the regenerated Verilog and records a CSV trace.
//
// There is no VHDL simulator here, so this testbench never runs against the
// design's own source - only against the Verilog hif2verilog regenerates from
// it. The expected trace is therefore computed by hand from the VHDL and
// checked in (expect_regenerated.csv), rather than captured from a reference
// run the way behavioral_roundtrip designs do.
//
// Each input combination is sampled twice, 1 ns and 3 ns after the change, so
// that w's 2 ns delay is visible in the trace: a dropped delay would make the
// two samples identical.
`timescale 1ns/1ps
module vhdl_concurrent_tb;
  reg a, b, c;
  wire y, z, w;
  integer fd;
  reg [4095:0] tracefile;

  vhdl_concurrent dut (.a(a), .b(b), .c(c), .y(y), .z(z), .w(w));

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,a,b,c,y,z,w");

    a = 1'b0; b = 1'b0; c = 1'b0;
    #10; $fdisplay(fd, "%0t,%b,%b,%b,%b,%b,%b", $time, a, b, c, y, z, w);

    a = 1'b1; b = 1'b1; c = 1'b0;
    #1;  $fdisplay(fd, "%0t,%b,%b,%b,%b,%b,%b", $time, a, b, c, y, z, w);
    #2;  $fdisplay(fd, "%0t,%b,%b,%b,%b,%b,%b", $time, a, b, c, y, z, w);

    a = 1'b1; b = 1'b0; c = 1'b0;
    #1;  $fdisplay(fd, "%0t,%b,%b,%b,%b,%b,%b", $time, a, b, c, y, z, w);
    #2;  $fdisplay(fd, "%0t,%b,%b,%b,%b,%b,%b", $time, a, b, c, y, z, w);

    a = 1'b0; b = 1'b0; c = 1'b1;
    #1;  $fdisplay(fd, "%0t,%b,%b,%b,%b,%b,%b", $time, a, b, c, y, z, w);
    #2;  $fdisplay(fd, "%0t,%b,%b,%b,%b,%b,%b", $time, a, b, c, y, z, w);

    $fclose(fd);
    $finish;
  end
endmodule
