// Drives the regenerated Verilog and records a CSV trace. There is no VHDL
// simulator here, so the expected trace is computed by hand from the VHDL and
// checked in (expect_regenerated.csv).
//
// a and b are chosen so that a, b, a and b, and a xor b are four different
// values - 1100, 1010, 1000, 0110 - which is what makes each alternative
// identifiable from the trace alone.
//
// The last step drives `sel` to x. That is what makes `when others` do work
// the three named alternatives cannot: VHDL's others covers the metavalues as
// well as 2'b11, so it has to come out as Verilog's `default` and not as the
// label 2'b11. Without this row the two spellings are indistinguishable -
// measured, by re-spelling it in the regenerated Verilog and re-running.
//
// The step before it is 2'b10, not 2'b11, for the same reason: `others` and
// 2'b10 give different answers, so a selector that matched nothing and left the
// process holding is distinguishable from one that reached `others`. Ordered
// the other way the hold and the correct answer are both 0110.
`timescale 1ns/1ps
module vhdl_case_tb;
  reg [1:0] sel;
  reg [3:0] a, b;
  wire [3:0] y;
  integer fd;
  reg [4095:0] tracefile;

  vhdl_case dut (.sel(sel), .a(a), .b(b), .y(y));

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

    a = 4'b1100;
    b = 4'b1010;
    step(2'b00);
    step(2'b01);
    step(2'b11);
    step(2'b10);
    step(2'bxx);

    $fclose(fd);
    $finish;
  end
endmodule
