// Free-running clock, sampled every falling edge for eighteen periods - long
// enough for four pulses, so the trace states a period rather than a single
// event.
//
// With the clock rising at 5 ns and every 10 ns after, the repeat consumes the
// edges at 5, 15 and 25, so:
//
//   t=30   pulse=1, pulses=1     the third edge released it
//   t=40   pulse=0, pulses=1     one clock wide, no more
//   t=70   pulse=1, pulses=2     and again four clocks later
//   t=110  pulse=1, pulses=3
//   t=150  pulse=1, pulses=4
//
// A repeat that ran a different number of times moves every one of those rows.
`timescale 1ns/1ps
module repeat_event_tb;
  reg clk;
  wire pulse;
  wire [3:0] pulses;
  integer i;
  integer fd;
  reg [4095:0] tracefile;

  repeat_event dut (.clk(clk), .pulse(pulse), .pulses(pulses));

  always #5 clk = ~clk;

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,pulse,pulses");

    clk = 1'b0;
    for (i = 0; i < 18; i = i + 1) begin
      @(negedge clk);
      $fdisplay(fd, "%0t,%b,%0d", $time, pulse, pulses);
    end

    $fclose(fd);
    $finish;
  end
endmodule
