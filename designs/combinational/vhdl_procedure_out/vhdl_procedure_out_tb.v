// Drives the regenerated Verilog and records a CSV trace.
//
// There is no VHDL simulator here, so this never runs against the design's own
// source - only against the Verilog hif2verilog regenerates from it. The
// expected trace is computed by hand from the VHDL and checked in.
//
// The whole truth table, in order, which is the natural thing to check on an
// adder and also happens to be what catches hif-backend#70: an out parameter
// copied back one activation late reports the *previous* row's sum and carry.
//
// The first row is the one that cannot be explained away - before any previous
// activation exists, a lagging copy-back has nothing to publish and the outputs
// read x. The later rows keep the check honest for a lag that survives past the
// first activation.
`timescale 1ns/1ps
module vhdl_procedure_out_tb;
  reg a, b, cin;
  wire s, cout;
  integer i;
  integer fd;
  reg [4095:0] tracefile;

  vhdl_procedure_out dut (.a(a), .b(b), .cin(cin), .s(s), .cout(cout));

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,a,b,cin,s,cout");

    for (i = 0; i < 8; i = i + 1) begin
      {a, b, cin} = i[2:0];
      #10; $fdisplay(fd, "%0t,%b,%b,%b,%b,%b", $time, a, b, cin, s, cout);
    end

    $fclose(fd);
    $finish;
  end
endmodule
