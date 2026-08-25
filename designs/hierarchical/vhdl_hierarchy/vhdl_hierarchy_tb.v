// Drives the regenerated Verilog and records a CSV trace. There is no VHDL
// simulator here, so the expected trace is computed by hand from the VHDL and
// checked in (expect_regenerated.csv).
//
// y0 and y1 come from two instances of the same cell wired with a and b in
// opposite orders, so every step reports two values that disagree. A port map
// read positionally instead of by name wires u1 like u0, and then y1 tracks y0
// on every row - measured, by re-spelling u1's connections in the regenerated
// Verilog and re-running.
`timescale 1ns/1ps
module vhdl_hierarchy_tb;
  reg [3:0] a, b;
  wire [3:0] y0, y1;
  integer fd;
  reg [4095:0] tracefile;

  vhdl_hierarchy dut (.a(a), .b(b), .y0(y0), .y1(y1));

  task step;
    input [3:0] va;
    input [3:0] vb;
    begin
      a = va;
      b = vb;
      #1 $fdisplay(fd, "%0t,%b,%b,%b,%b", $time, a, b, y0, y1);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,a,b,y0,y1");

    step(4'b1100, 4'b1010);
    step(4'b1111, 4'b0000);
    step(4'b0000, 4'b1111);

    $fclose(fd);
    $finish;
  end
endmodule
