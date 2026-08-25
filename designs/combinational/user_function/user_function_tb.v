// Drives both call sites and records a CSV trace.
//
// The pairs walk the function's branch deliberately: below the cap, exactly at
// it, one over, and far over. `capped_aa` doubles `a`, so each step also
// exercises the same function with both actuals equal - a second call site
// with a different argument shape.
//
//   a  b   x+y  capped_ab   a+a  capped_aa
//   0  0     0          0     0          0   both branches idle
//   3  5     8          8     6          6   below the cap
//  10 10    20         20    20         20   exactly at it, not clamped
//  11 10    21         20    22         20   one over, clamped
//  15 15    30         20    30         20   far over, still 20
//  12  4    16         16    24         20   back below on one side only
`timescale 1ns/1ps
module user_function_tb;
  reg [3:0] a, b;
  wire [4:0] capped_ab, capped_aa;
  integer fd;
  reg [4095:0] tracefile;

  user_function dut (.a(a), .b(b), .capped_ab(capped_ab), .capped_aa(capped_aa));

  task step;
    input [3:0] xa;
    input [3:0] xb;
    begin
      a = xa;
      b = xb;
      #1 $fdisplay(fd, "%0t,%0d,%0d,%0d,%0d", $time, a, b, capped_ab, capped_aa);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,a,b,capped_ab,capped_aa");

    step(4'd0,  4'd0);
    step(4'd3,  4'd5);
    step(4'd10, 4'd10);
    step(4'd11, 4'd10);
    step(4'd15, 4'd15);
    step(4'd12, 4'd4);

    $fclose(fd);
    $finish;
  end
endmodule
