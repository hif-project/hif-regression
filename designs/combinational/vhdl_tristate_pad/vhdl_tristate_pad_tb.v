// Drives the regenerated Verilog and records a CSV trace.
//
// There is no VHDL simulator here, so this testbench never runs against the
// design's own source - only against the Verilog hif2verilog regenerates from
// it. The expected trace is computed by hand from the VHDL and checked in
// (expect_regenerated.csv).
//
// The testbench is itself the second device on the pin. Without an external
// driver none of the interesting properties are observable: a lowering that
// drove the pin unconditionally, or one that let the device sample its own
// driver instead of the wire, produces exactly the same trace as a correct one
// as long as nobody else is driving.
`timescale 1ns/1ps
module vhdl_tristate_pad_tb;
  reg oe, din;
  reg ext_oe, ext_din;
  wire pad;
  wire dout;
  integer fd;
  reg [4095:0] tracefile;

  vhdl_tristate_pad dut (.oe(oe), .din(din), .pad(pad), .dout(dout));

  // The other device on the pin.
  assign pad = ext_oe ? ext_din : 1'bz;

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,oe,din,ext_oe,ext_din,pad,dout");

    // Driving, both polarities. The pin carries din.
    oe = 1'b1; din = 1'b0; ext_oe = 1'b0; ext_din = 1'b0;
    #10; $fdisplay(fd, "%0t,%b,%b,%b,%b,%b,%b", $time, oe, din, ext_oe, ext_din, pad, dout);

    din = 1'b1;
    #10; $fdisplay(fd, "%0t,%b,%b,%b,%b,%b,%b", $time, oe, din, ext_oe, ext_din, pad, dout);

    // Released, and nobody else driving: the pin floats.
    oe = 1'b0;
    #10; $fdisplay(fd, "%0t,%b,%b,%b,%b,%b,%b", $time, oe, din, ext_oe, ext_din, pad, dout);

    // Released, the other device driving: the pin carries *its* value, and
    // dout has to follow the pin rather than the value this device last drove.
    ext_oe = 1'b1; ext_din = 1'b1;
    #10; $fdisplay(fd, "%0t,%b,%b,%b,%b,%b,%b", $time, oe, din, ext_oe, ext_din, pad, dout);

    ext_din = 1'b0;
    #10; $fdisplay(fd, "%0t,%b,%b,%b,%b,%b,%b", $time, oe, din, ext_oe, ext_din, pad, dout);

    // Both driving, opposite values: a real bidirectional pin resolves this to
    // x, which is only observable because both drivers are genuinely present.
    oe = 1'b1; din = 1'b1;
    #10; $fdisplay(fd, "%0t,%b,%b,%b,%b,%b,%b", $time, oe, din, ext_oe, ext_din, pad, dout);

    $fclose(fd);
    $finish;
  end
endmodule
