// Drives the regenerated Verilog and records a CSV trace. There is no VHDL
// simulator here, so the expected trace is computed by hand from the VHDL and
// checked in (expect_regenerated.csv).
//
// Each step presents its inputs during the low phase, lets the rising edge
// capture them, and then moves `d` again while the clock is high, leaving it
// moved over the sample. A process whose sensitivity list was rebuilt from the
// signals it reads rather than from the edge is a latch, and it follows `d`
// the moment it changes; the rows where the reset is low therefore show `q`
// holding what the edge captured while the pins say something else.
//
// `d` is non-zero on both reset rows, so a reset that went missing shows as a
// value in q rather than as a row that was going to be zero anyway.
`timescale 1ns/1ps
module vhdl_event_edge_tb;
  reg clk, rst;
  reg [3:0] d;
  wire [3:0] q;
  integer fd;
  reg [4095:0] tracefile;

  vhdl_event_edge dut (.clk(clk), .rst(rst), .d(d), .q(q));

  always #5 clk = ~clk;

  task step;
    input xrst;
    input [3:0] xd;
    input [3:0] after_edge;
    begin
      rst = xrst;
      d   = xd;
      @(posedge clk);
      #2 d = after_edge;
      #5 $fdisplay(fd, "%0t,%b,%b,%b", $time, rst, d, q);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,rst,d,q");

    clk = 1'b0;
    step(1'b1, 4'b1010, 4'b1111);
    step(1'b0, 4'b1010, 4'b0000);
    step(1'b0, 4'b0101, 4'b1111);
    step(1'b1, 4'b1100, 4'b0011);
    step(1'b0, 4'b1111, 4'b0110);

    $fclose(fd);
    $finish;
  end
endmodule
