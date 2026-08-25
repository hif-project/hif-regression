// Pairs that separate a signed comparison from an unsigned one on the bit
// patterns alone.
//
//    a   b   lt ge eq   signed says          unsigned would say
//   -1   1    1  0  0   -1 < 1               15 < 1 is false
//    1  -1    0  1  0   1 > -1               1 < 15 is true
//   -8   7    1  0  0   -8 < 7               8 < 7 is false
//    7  -8    0  1  0   7 > -8               7 < 8 is true
//    3   3    0  1  1   equal either way     equal either way
//   -4  -2    1  0  0   -4 < -2              12 < 14, also true
//
// The first four rows invert under an unsigned reading. The last two do not,
// and are here as controls: `eq` never changes, and two negatives compare the
// same way under both readings, so a trace that differed everywhere would
// point at something other than signedness.
`timescale 1ns/1ps
module signed_compare_tb;
  reg signed [3:0] a, b;
  wire lt, ge, eq;
  integer fd;
  reg [4095:0] tracefile;

  signed_compare dut (.a(a), .b(b), .lt(lt), .ge(ge), .eq(eq));

  task step;
    input signed [3:0] xa;
    input signed [3:0] xb;
    begin
      a = xa;
      b = xb;
      #1 $fdisplay(fd, "%0t,%0d,%0d,%b,%b,%b", $time, a, b, lt, ge, eq);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,a,b,lt,ge,eq");

    step(-4'sd1,  4'sd1);
    step( 4'sd1, -4'sd1);
    step(-4'sd8,  4'sd7);
    step( 4'sd7, -4'sd8);
    step( 4'sd3,  4'sd3);
    step(-4'sd4, -4'sd2);

    $fclose(fd);
    $finish;
  end
endmodule
