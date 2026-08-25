// Drives the regenerated Verilog and records a CSV trace. There is no VHDL
// simulator here, so the expected trace is computed by hand from the VHDL and
// checked in (expect_regenerated.csv).
//
// VHDL's `and` on two vectors of equal length pairs them element by element
// left to right, so MASK's leftmost bit meets a's leftmost bit regardless of
// how the two are indexed. The mask keeps the high half and drops the low
// half. "1100" is not a palindrome, so a mask that arrived reversed gives a
// different answer on the two mixed rows instead of the same one.
`timescale 1ns/1ps
module vhdl_ascending_literal_tb;
  reg [3:0] a;
  wire [3:0] y;
  integer fd;
  reg [4095:0] tracefile;

  vhdl_ascending_literal dut (.a(a), .y(y));

  task step;
    input [3:0] va;
    begin
      a = va;
      #1 $fdisplay(fd, "%0t,%b,%b", $time, a, y);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,a,y");

    step(4'b1111);
    step(4'b0011);
    step(4'b1010);
    step(4'b0101);

    $fclose(fd);
    $finish;
  end
endmodule
