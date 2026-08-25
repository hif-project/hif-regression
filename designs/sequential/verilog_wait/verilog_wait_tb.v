// Holds `gate` high across several clock periods, drops it, and raises it
// again, sampling every falling edge.
//
// The clock rises at 5 ns and every 10 ns after. What the trace has to show:
//
//   t=10..30    gate=0, count=0       suspended, no edge is taken
//   t=40..70    gate=1, count=1..4    one count per rising edge while high
//   t=80        gate=0, count=5       the edge at 75 was already committed
//   t=90,100    gate=0, count=5       suspended again, and stays put
//   t=110..130  gate=1, count=6..8    resumes on the level, not on an edge
//
// The rows from t=50 on are what distinguish a level-sensitive wait: `gate` has
// not changed since 30 ns, so a wait that resumed on a change would suspend on
// re-entry and leave count at 1 for the rest of the run.
`timescale 1ns/1ps
module verilog_wait_tb;
  reg clk, gate;
  wire [3:0] count;
  integer fd;
  reg [4095:0] tracefile;

  verilog_wait dut (.clk(clk), .gate(gate), .count(count));

  always #5 clk = ~clk;

  task sample;
    begin
      @(negedge clk);
      $fdisplay(fd, "%0t,%b,%0d", $time, gate, count);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,gate,count");

    clk = 1'b0;
    gate = 1'b0;
    repeat (3) sample;

    gate = 1'b1;
    repeat (4) sample;

    gate = 1'b0;
    repeat (3) sample;

    gate = 1'b1;
    repeat (3) sample;

    $fclose(fd);
    $finish;
  end
endmodule
