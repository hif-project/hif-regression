// Drives the regenerated Verilog and records a CSV trace.
//
// There is no VHDL simulator here, so this never runs against the design's own
// source - only against the Verilog hif2verilog regenerates from it. The
// expected trace is computed by hand from the VHDL and checked in.
//
// The testbench owns bus lines 3..2, which is the entire point: the device
// under test never assigns them, so whether its driver correctly contributes
// *nothing* there is observable only when somebody else is driving them. With
// no second driver the lines would read x or z either way and the design would
// pass while broken.
`timescale 1ns/1ps
module vhdl_shared_bus_tb;
  reg sel;
  reg [1:0] code;
  reg [1:0] ext_high;
  wire [3:0] bus_lines;
  integer fd;
  reg [4095:0] tracefile;

  vhdl_shared_bus dut (.sel(sel), .code(code), .bus_lines(bus_lines));

  // The other device on the bus. It owns lines 3..2 and never touches 1..0.
  assign bus_lines[3:2] = ext_high;

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,sel,code,ext_high,bus_lines");

    // Not selected: this device is off its lines, the other device holds its.
    sel = 1'b0; code = 2'b00; ext_high = 2'b10;
    #10; $fdisplay(fd, "%0t,%b,%b,%b,%b", $time, sel, code, ext_high, bus_lines);

    // Selected: it answers on 1..0 and still must not disturb 3..2.
    sel = 1'b1; code = 2'b01;
    #10; $fdisplay(fd, "%0t,%b,%b,%b,%b", $time, sel, code, ext_high, bus_lines);

    code = 2'b11;
    #10; $fdisplay(fd, "%0t,%b,%b,%b,%b", $time, sel, code, ext_high, bus_lines);

    // Released again.
    sel = 1'b0;
    #10; $fdisplay(fd, "%0t,%b,%b,%b,%b", $time, sel, code, ext_high, bus_lines);

    // The other device changes its lines while this one answers.
    ext_high = 2'b01; sel = 1'b1; code = 2'b10;
    #10; $fdisplay(fd, "%0t,%b,%b,%b,%b", $time, sel, code, ext_high, bus_lines);

    $fclose(fd);
    $finish;
  end
endmodule
