// Drives the regenerated Verilog and records a CSV trace. There is no VHDL
// simulator here, so the expected trace is computed by hand from the VHDL and
// checked in (expect_regenerated.csv).
//
// The design clears a's top bit, so every step with that bit set reports a
// value the unsliced regeneration cannot produce: hif2verilog emits
// `assign y = {1'b0, a}`, seven bits into a six-bit net, which truncates back
// to a and leaves the top bit standing.
//
// The generic is left at its default. Overriding it from a generic map is a
// different question and belongs to a different design.
`timescale 1ns/1ps
module vhdl_generic_width_tb;
  reg [5:0] a;
  wire [5:0] y;
  integer fd;
  reg [4095:0] tracefile;

  vhdl_generic_width dut (.a(a), .y(y));

  task step;
    input [5:0] va;
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

    step(6'b111111);
    step(6'b101010);
    step(6'b010101);
    step(6'b100000);

    $fclose(fd);
    $finish;
  end
endmodule
