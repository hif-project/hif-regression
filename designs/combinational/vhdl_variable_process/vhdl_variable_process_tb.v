// Drives the regenerated Verilog and records a CSV trace. There is no VHDL
// simulator here, so the expected trace is computed by hand from the VHDL and
// checked in (expect_regenerated.csv).
//
// `a and b` alternates between 0 and 1 on every step. That is deliberate: a
// variable flattened into a signal publishes the previous execution's value,
// so `y` would carry the step before it and disagree on every single row.
`timescale 1ns/1ps
module vhdl_variable_process_tb;
  reg a, b, c;
  wire y, z;
  integer fd;
  reg [4095:0] tracefile;

  vhdl_variable_process dut (.a(a), .b(b), .c(c), .y(y), .z(z));

  task step;
    input xa;
    input xb;
    input xc;
    begin
      a = xa;
      b = xb;
      c = xc;
      #1 $fdisplay(fd, "%0t,%b,%b,%b,%b,%b", $time, a, b, c, y, z);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,a,b,c,y,z");

    step(1'b0, 1'b0, 1'b0);
    step(1'b1, 1'b1, 1'b0);
    step(1'b1, 1'b0, 1'b0);
    step(1'b1, 1'b1, 1'b1);
    step(1'b0, 1'b1, 1'b1);
    step(1'b1, 1'b1, 1'b0);

    $fclose(fd);
    $finish;
  end
endmodule
