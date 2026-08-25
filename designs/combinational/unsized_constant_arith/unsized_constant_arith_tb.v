// Walks up to the top of four bits, because the top is where the two widths
// stop agreeing.
//
//    a   inc  wide_inc  dbl    what the row states
//    0     1         1    0    nothing overflows
//    7     8         8   14    still inside four bits
//   14    15        15   12    a*2 = 28 has already wrapped
//   15     0        16   14    the row that matters: same expression, two widths
//    9    10        10    2    a*2 = 18 wraps to 2
//
// The fourth row is the whole design: `inc` and `wide_inc` are written from the
// identical expression and must differ, because their targets differ. A trace
// where they agree has lost the assignment context.
`timescale 1ns/1ps
module unsized_constant_arith_tb;
  reg [3:0] a;
  wire [3:0] inc, dbl;
  wire [4:0] wide_inc;
  integer fd;
  reg [4095:0] tracefile;

  unsized_constant_arith dut (.a(a), .inc(inc), .wide_inc(wide_inc), .dbl(dbl));

  task step;
    input [3:0] x;
    begin
      a = x;
      #1 $fdisplay(fd, "%0t,%0d,%0d,%0d,%0d", $time, a, inc, wide_inc, dbl);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,a,inc,wide_inc,dbl");

    step(4'd0);
    step(4'd7);
    step(4'd14);
    step(4'd15);
    step(4'd9);

    $fclose(fd);
    $finish;
  end
endmodule
