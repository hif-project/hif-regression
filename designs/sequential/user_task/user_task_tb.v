// Drives the design and records a CSV trace, sampled on the falling edge so
// every row reads the values the task published on the rising edge before it.
//
// Consecutive steps deliberately disagree about which argument is larger:
//
//   a   b    upper  lower   why this step is here
//   3   5        5      3   the else branch
//   9   2        9      2   the then branch, and a swap from the step before
//   7   7        7      7   equal operands take the `>=` branch
//   0  15       15      0   the widest separation, both outputs move
//   6   1        6      1   swaps back
//
// Every row differs from the one before it in both outputs, so a copy-back
// that publishes the previous call's values - hif-backend#70 - moves every row
// down by one rather than perturbing a single sample.
`timescale 1ns/1ps
module user_task_tb;
  reg clk;
  reg [3:0] a, b;
  wire [3:0] upper, lower;
  integer fd;
  reg [4095:0] tracefile;

  user_task dut (.clk(clk), .a(a), .b(b), .upper(upper), .lower(lower));

  always #5 clk = ~clk;

  task step;
    input [3:0] xa;
    input [3:0] xb;
    begin
      a = xa;
      b = xb;
      @(negedge clk);
      $fdisplay(fd, "%0t,%0d,%0d,%0d,%0d", $time, a, b, upper, lower);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,a,b,upper,lower");

    clk = 1'b0;
    step(4'd3,  4'd5);
    step(4'd9,  4'd2);
    step(4'd7,  4'd7);
    step(4'd0,  4'd15);
    step(4'd6,  4'd1);

    $fclose(fd);
    $finish;
  end
endmodule
