// Visits every label of both alternatives and two values that only the default
// can serve.
//
// With a = 1100 and b = 1010, so that a, b and a^b = 0110 are all different:
//
//   sel  y      which alternative
//     0  1100   first, label one of three
//     1  1100   first, label two
//     2  1100   first, label three
//     3  1010   second, label one of two
//     4  1010   second, label two
//     5  0110   default
//     7  0110   default again, from the top of the range
//
// Every label is visited on its own, so a label dropped from a list is a
// single row that changes to 0110 - not a whole alternative disappearing.
`timescale 1ns/1ps
module case_multi_labels_tb;
  reg [2:0] sel;
  reg [3:0] a, b;
  wire [3:0] y;
  integer fd;
  reg [4095:0] tracefile;

  case_multi_labels dut (.sel(sel), .a(a), .b(b), .y(y));

  task step;
    input [2:0] s;
    begin
      sel = s;
      #1 $fdisplay(fd, "%0t,%0d,%b,%b,%b", $time, sel, a, b, y);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,sel,a,b,y");

    a = 4'b1100;
    b = 4'b1010;
    step(3'd0);
    step(3'd1);
    step(3'd2);
    step(3'd3);
    step(3'd4);
    step(3'd5);
    step(3'd7);

    $fclose(fd);
    $finish;
  end
endmodule
