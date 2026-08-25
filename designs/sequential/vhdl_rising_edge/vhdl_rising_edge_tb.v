// Drives the regenerated Verilog and records a CSV trace.
//
// There is no VHDL simulator here, so this testbench never runs against the
// design's own source - only against the Verilog hif2verilog regenerates from
// it. The expected trace is computed by hand from the VHDL and checked in
// (expect_regenerated.csv).
//
// Each step sets the inputs during the low phase, lets the rising edge capture
// them, and then *moves `d` again while the clock is high* and leaves it there
// over the sample. That last part is what makes the trace a statement about
// edge sensitivity rather than about values: a process whose sensitivity list
// was rebuilt from the signals it reads - `always @(clk or en or d)` - is a
// latch, and it follows `d` to the new value the moment it changes. The rows
// where `en` is high therefore show `q` holding what the edge captured while
// `d` on the pins says something else.
`timescale 1ns/1ps
module vhdl_rising_edge_tb;
  reg clk, en;
  reg [3:0] d;
  wire [3:0] q;
  integer fd;
  reg [4095:0] tracefile;

  vhdl_rising_edge dut (.clk(clk), .en(en), .d(d), .q(q));

  always #5 clk = ~clk;

  task step;
    input xen;
    input [3:0] xd;
    input [3:0] after_edge;
    begin
      en = xen;
      d  = xd;
      @(posedge clk);
      #2 d = after_edge;
      #5 $fdisplay(fd, "%0t,%b,%b,%b", $time, en, d, q);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,en,d,q");

    clk = 1'b0;
    step(1'b1, 4'b0101, 4'b1111);
    step(1'b0, 4'b1001, 4'b0000);
    step(1'b1, 4'b1100, 4'b0011);
    step(1'b0, 4'b1010, 4'b0101);
    step(1'b1, 4'b0110, 4'b1001);

    $fclose(fd);
    $finish;
  end
endmodule
