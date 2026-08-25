// Steps `d` to a different value every cycle, sampled on the falling edge.
//
//   d    a    b     what the row states
//   0    1    2     b is a+1 computed from the a of this edge
//   5    6    7
//   9   10   11
//  14   15    0     b wraps in four bits where a does not
//   1    2    3
//
// The claim is the relationship *within* a row: b = a + 1 always. Under
// non-blocking assignment b would carry the previous row's a plus one - 2, 2,
// 7, 11, 0 for this stimulus - so every row after the first disagrees. The
// jumps in d are deliberately uneven, which stops a lagging b from coinciding
// with a correct one.
`timescale 1ns/1ps
module blocking_dependency_tb;
  reg clk;
  reg [3:0] d;
  wire [3:0] a, b;
  integer fd;
  reg [4095:0] tracefile;

  blocking_dependency dut (.clk(clk), .d(d), .a(a), .b(b));

  always #5 clk = ~clk;

  task step;
    input [3:0] xd;
    begin
      d = xd;
      @(negedge clk);
      $fdisplay(fd, "%0t,%0d,%0d,%0d", $time, d, a, b);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,d,a,b");

    clk = 1'b0;
    step(4'd0);
    step(4'd5);
    step(4'd9);
    step(4'd14);
    step(4'd1);

    $fclose(fd);
    $finish;
  end
endmodule
