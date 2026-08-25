// Drives every combination of the two data bits and samples on the falling
// edge, so each row reads what the rising edge before it wrote.
//
//   rst d0 d1    q      why
//     1  0  0  0000   the whole-vector branch clears all four
//     0  1  0  0101   q0=1, q1=0, q2=1^0=1, q3=previous q2=0
//     0  1  1  1011   q2=1^1=0, q3=previous q2=1
//     0  0  1  0110   q2=0^1=1, q3=previous q2=0
//     0  0  0  1000   q2=0^0=0, q3=previous q2=1
//     0  1  0  0101   back to the second row's pattern
//     1  0  0  0000   and the reset branch again, after per-bit writes
//
// No two consecutive rows agree, and q3 lags q2 by a cycle, so a bit written
// from the wrong index moves this trace rather than happening to land on the
// same value.
`timescale 1ns/1ps
module procedural_bit_select_tb;
  reg clk, rst, d0, d1;
  wire [3:0] q;
  integer fd;
  reg [4095:0] tracefile;

  procedural_bit_select dut (.clk(clk), .rst(rst), .d0(d0), .d1(d1), .q(q));

  always #5 clk = ~clk;

  task step;
    input xrst;
    input xd0;
    input xd1;
    begin
      rst = xrst;
      d0  = xd0;
      d1  = xd1;
      @(negedge clk);
      $fdisplay(fd, "%0t,%b,%b,%b,%b", $time, rst, d0, d1, q);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,rst,d0,d1,q");

    clk = 1'b0;
    step(1'b1, 1'b0, 1'b0);
    step(1'b0, 1'b1, 1'b0);
    step(1'b0, 1'b1, 1'b1);
    step(1'b0, 1'b0, 1'b1);
    step(1'b0, 1'b0, 1'b0);
    step(1'b0, 1'b1, 1'b0);
    step(1'b1, 1'b0, 1'b0);

    $fclose(fd);
    $finish;
  end
endmodule
