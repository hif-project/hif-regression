// Drives the regenerated Verilog and records a CSV trace. There is no VHDL
// simulator here, so the expected trace is computed by hand from the VHDL and
// checked in (expect_regenerated.csv).
//
// Two of the five pairs take the early return and three fall through to the
// statement after it, so neither path can be the one that always runs. The
// pairs where `a` is the larger are the ones that matter: those are the rows
// an early return that failed to leave the function would get wrong, because
// the statement below would overwrite the answer with `b`.
`timescale 1ns/1ps
module vhdl_user_function_tb;
  reg [3:0] a, b;
  wire [3:0] y;
  integer fd;
  reg [4095:0] tracefile;

  vhdl_user_function dut (.a(a), .b(b), .y(y));

  task step;
    input [3:0] xa;
    input [3:0] xb;
    begin
      a = xa;
      b = xb;
      #1 $fdisplay(fd, "%0t,%b,%b,%b", $time, a, b, y);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,a,b,y");

    step(4'b1100, 4'b1010);
    step(4'b0011, 4'b1000);
    step(4'b0101, 4'b0101);
    step(4'b1111, 4'b0000);
    step(4'b0000, 4'b1111);

    $fclose(fd);
    $finish;
  end
endmodule
