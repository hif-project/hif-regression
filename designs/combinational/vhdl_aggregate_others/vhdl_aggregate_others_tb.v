// Drives the regenerated Verilog and records a CSV trace. There is no VHDL
// simulator here, so the expected trace is computed by hand from the VHDL and
// checked in (expect_regenerated.csv).
//
// xor rather than and or or: it is the only one of the three that makes every
// bit of the constant observable from a single stimulus value, because it
// passes a through where the constant is 0 and inverts it where the constant
// is 1. A masking operator hides half the constant on any given row.
`timescale 1ns/1ps
module vhdl_aggregate_others_tb;
  reg [7:0] a;
  wire [7:0] y;
  integer fd;
  reg [4095:0] tracefile;

  vhdl_aggregate_others dut (.a(a), .y(y));

  task step;
    input [7:0] va;
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

    step(8'b00000000);
    step(8'b11111111);
    step(8'b00101000);
    step(8'b10100000);

    $fclose(fd);
    $finish;
  end
endmodule
