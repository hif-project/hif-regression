// Walks the position past the top of four bits and back, sampled on the
// falling edge.
//
//   rst step   pos wrapped   what the row states
//     1    0     0       0   the clear argument, an ordinary `input`
//     0    3     3       0   the inout argument carries the total forward
//     0    3     6       0
//     0    3     9       0
//     0    3    12       0
//     0    3    15       0   the last total that fits
//     0    3     2       1   15 + 3 = 18: wraps, and the output argument says so
//     0    3     5       0   and the flag clears again on the next call
//     1    3     0       0   clear once more, after the wrap
//
// The inout argument is the whole claim here: a copy-in that read the wrong
// value, or a copy-back that never happened, leaves `pos` at 0 for the entire
// run - which is exactly what verilog_task_arguments does today on
// hif-frontend#31, and exactly what this design must not do.
`timescale 1ns/1ps
module ansi_task_ports_tb;
  reg clk, rst;
  reg [3:0] step;
  wire [3:0] pos;
  wire wrapped;
  integer fd;
  reg [4095:0] tracefile;

  ansi_task_ports dut (.clk(clk), .rst(rst), .step(step), .pos(pos), .wrapped(wrapped));

  always #5 clk = ~clk;

  task tick;
    begin
      @(negedge clk);
      $fdisplay(fd, "%0t,%b,%0d,%0d,%b", $time, rst, step, pos, wrapped);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,rst,step,pos,wrapped");

    clk = 1'b0;
    rst = 1'b1;
    step = 4'd0;
    tick;

    rst = 1'b0;
    step = 4'd3;
    repeat (7) tick;

    rst = 1'b1;
    tick;

    $fclose(fd);
    $finish;
  end
endmodule
