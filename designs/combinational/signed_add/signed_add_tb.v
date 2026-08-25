// Pairs chosen so that the sign matters on every row: one negative operand,
// two negatives, and the two extremes of a four-bit signed range.
//
//    a   b   wide  narrow    what the row states
//    3   2      5       5    both positive, nothing to sign-extend
//   -3   2     -1      -1    a negative sum: zero extension gives 15 instead
//   -5  -4     -9       7    two negatives; narrow truncates to +7
//    7   7     14      -2    positive overflow into the narrow result
//   -8  -1     -9       7    the most negative operand
//    7  -8     -1      -1    the two extremes, summing to -1
//
// `wide` is five bits and holds every sum; `narrow` is four and wraps. The
// pair is what separates a lost sign from a lost width - a zero-extending
// backend gets `wide` wrong while `narrow`, which truncates anyway, still
// agrees on most rows.
`timescale 1ns/1ps
module signed_add_tb;
  reg signed [3:0] a, b;
  wire signed [4:0] wide;
  wire signed [3:0] narrow;
  integer fd;
  reg [4095:0] tracefile;

  signed_add dut (.a(a), .b(b), .wide(wide), .narrow(narrow));

  task step;
    input signed [3:0] xa;
    input signed [3:0] xb;
    begin
      a = xa;
      b = xb;
      #1 $fdisplay(fd, "%0t,%0d,%0d,%0d,%0d", $time, a, b, wide, narrow);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,a,b,wide,narrow");

    step( 4'sd3,  4'sd2);
    step(-4'sd3,  4'sd2);
    step(-4'sd5, -4'sd4);
    step( 4'sd7,  4'sd7);
    step(-4'sd8, -4'sd1);
    step( 4'sd7, -4'sd8);

    $fclose(fd);
    $finish;
  end
endmodule
