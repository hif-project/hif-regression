// Drives the design and records a CSV trace.
//
// Unlike the VHDL designs here, this one is Verilog, so its own source can be
// simulated: the pipeline runs this testbench against the original RTL and
// against the regenerated RTL and requires identical traces. No expected trace
// is checked in - the claim is that the round trip preserved behavior, and
// pinning absolute values would freeze this testbench's stimulus into the
// corpus as if it were the specification.
//
// The stimulus walks the accumulator up to and past saturation, so the trace
// covers the task's inout argument carrying state across calls, its output
// argument reporting a flag, and both branches of the body.
`timescale 1ns/1ps
module verilog_task_arguments_tb;
  reg clk, rst;
  reg [3:0] delta;
  wire [3:0] acc;
  wire sat;
  integer i;
  integer fd;
  reg [4095:0] tracefile;

  verilog_task_arguments dut (.clk(clk), .rst(rst), .delta(delta), .acc(acc), .sat(sat));

  always #5 clk = ~clk;

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,rst,delta,acc,sat");

    clk = 1'b0;
    rst = 1'b1;
    delta = 4'd0;
    @(negedge clk);
    $fdisplay(fd, "%0t,%b,%b,%b,%b", $time, rst, delta, acc, sat);

    // Accumulate below saturation: the inout argument has to carry the running
    // total from one call to the next.
    rst = 1'b0;
    delta = 4'd3;
    for (i = 0; i < 4; i = i + 1) begin
      @(negedge clk);
      $fdisplay(fd, "%0t,%b,%b,%b,%b", $time, rst, delta, acc, sat);
    end

    // Push past the top: the output argument has to report it, and the total
    // has to clamp rather than wrap.
    delta = 4'd7;
    for (i = 0; i < 3; i = i + 1) begin
      @(negedge clk);
      $fdisplay(fd, "%0t,%b,%b,%b,%b", $time, rst, delta, acc, sat);
    end

    // Back under the limit clears the flag again.
    rst = 1'b1;
    @(negedge clk);
    $fdisplay(fd, "%0t,%b,%b,%b,%b", $time, rst, delta, acc, sat);
    rst = 1'b0;
    delta = 4'd1;
    for (i = 0; i < 2; i = i + 1) begin
      @(negedge clk);
      $fdisplay(fd, "%0t,%b,%b,%b,%b", $time, rst, delta, acc, sat);
    end

    $fclose(fd);
    $finish;
  end
endmodule
