// Samples on the falling edge, either side of the one release, and keeps
// sampling long after it.
//
// With the clock rising at 5 ns and every 10 ns after, and the reset released
// at 12 ns:
//
//   t=10   rst_n=0, count=0    the reset held over the first rising edge
//   t=20   rst_n=1, count=1    released once, the counter starts
//   t=30+  rst_n=1, count=2..  and keeps going, one per clock
//
// The tail is the point. A body replayed instead of run once puts rst_n back to
// 0 in the same instant it reaches 1, so count never leaves 0 - a difference
// that only shows up in rows after the release, not at it.
`timescale 1ns/1ps
module initial_block_tb;
  reg clk;
  wire rst_n;
  wire [3:0] count;
  integer i;
  integer fd;
  reg [4095:0] tracefile;

  initial_block dut (.clk(clk), .rst_n(rst_n), .count(count));

  always #5 clk = ~clk;

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,rst_n,count");

    clk = 1'b0;
    for (i = 0; i < 12; i = i + 1) begin
      @(negedge clk);
      $fdisplay(fd, "%0t,%b,%0d", $time, rst_n, count);
    end

    $fclose(fd);
    $finish;
  end
endmodule
