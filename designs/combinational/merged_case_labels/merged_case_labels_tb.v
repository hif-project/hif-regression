// Walks every select value twice, under two different data patterns, and
// visits the merged pair from both directions.
//
// With a = 1010 and b = 0110:
//
//   sel=00  y=1010   the merged alternative, first label
//   sel=01  y=1010   the merged alternative, second label
//   sel=10  y=0110   an unmerged alternative
//   sel=11  y=1001   the other unmerged alternative
//
// then with a = 0001 and b = 1100 the same four, in the order 01, 00, 11, 10.
//
// The second sweep enters the merged alternative through 2'b01 while the
// previous row was a *different* alternative, so a label dropped in the merge
// shows up as `y` holding 1001 rather than becoming 0001 - the hold a lost
// label creates, rather than a value that merely happens to agree.
`timescale 1ns/1ps
module merged_case_labels_tb;
  reg [1:0] sel;
  reg [3:0] a, b;
  wire [3:0] y;
  integer fd;
  reg [4095:0] tracefile;

  merged_case_labels dut (.sel(sel), .a(a), .b(b), .y(y));

  task step;
    input [1:0] s;
    begin
      sel = s;
      #1 $fdisplay(fd, "%0t,%b,%b,%b,%b", $time, sel, a, b, y);
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

    a = 4'b1010; b = 4'b0110;
    step(2'b00); step(2'b01); step(2'b10); step(2'b11);

    a = 4'b0001; b = 4'b1100;
    step(2'b01); step(2'b00); step(2'b11); step(2'b10);

    $fclose(fd);
    $finish;
  end
endmodule
