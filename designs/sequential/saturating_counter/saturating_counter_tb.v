// Stimulus for saturating_counter, shared by the reference and the
// instrumented compile. The activation port exists only in the instrumented
// netlist.
//
// Rising edges fall at 5, 15, 25 and every ten thereafter. Reset is released at
// 12 - off the clock grid, so no stimulus changes at the instant of an edge -
// and every row is sampled seven units after the edge it reports.
//
// The run is long enough to reach saturation and then stay there for four more
// cycles. That tail is not padding: the hold-branch fault is invisible until
// the counter saturates, so without cycles past saturation it would look like
// no fault at all.
`timescale 1ns/1ps
module saturating_counter_tb;
  reg clk, rst;
  wire [3:0] count;
  integer mut;
  integer fd;
  integer i;
  reg [4095:0] tracefile;

  saturating_counter dut (
    .clk(clk), .rst(rst), .count(count)
`ifdef MUFFIN_MUT
    , .muffinMutPort(mut)
`endif
  );

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    if (!$value$plusargs("mut=%d", mut)) mut = 0;
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,rst,count");

    rst = 1;
    #12 $fdisplay(fd, "%0t,%b,%b", $time, rst, count);
    rst = 0;
    for (i = 0; i < 13; i = i + 1) begin
      #10 $fdisplay(fd, "%0t,%b,%b", $time, rst, count);
    end

    $fclose(fd);
    $finish;
  end
endmodule
