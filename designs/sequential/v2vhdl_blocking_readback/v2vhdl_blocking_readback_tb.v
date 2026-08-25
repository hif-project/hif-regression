// Shared by both compiles in the pipeline: the untouched RTL and the same
// design after a full excursion through VHDL and back.
//
// Rising edges fall at 5, 15, 25, 35. Inputs move at 12, 22 and 32 - off the
// clock grid, so no stimulus ever changes at the instant of an edge - and each
// row is sampled a full half-cycle after the edge it reports.
//
// Adjacent edges never share an intermediate. A stale read is self-consistent:
// where acc happens to be unchanged from the edge before, the stale and fresh
// values coincide and the trace cannot separate them. acc runs 0110, 1100,
// 1111, 1100, so every row moves if the read goes stale.
`timescale 1ns/1ps
module v2vhdl_blocking_readback_tb;
  reg clk;
  reg [3:0] a, b;
  wire [3:0] acc, q;
  integer fd;
  reg [4095:0] tracefile;

  v2vhdl_blocking_readback dut (.clk(clk), .a(a), .b(b), .acc(acc), .q(q));

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,a,b,acc,q");

    a = 4'b1100; b = 4'b1010;
    #12 $fdisplay(fd, "%0t,%b,%b,%b,%b", $time, a, b, acc, q);
    a = 4'b0011; b = 4'b1111;
    #10 $fdisplay(fd, "%0t,%b,%b,%b,%b", $time, a, b, acc, q);
    a = 4'b1111; b = 4'b0000;
    #10 $fdisplay(fd, "%0t,%b,%b,%b,%b", $time, a, b, acc, q);
    a = 4'b0101; b = 4'b1001;
    #10 $fdisplay(fd, "%0t,%b,%b,%b,%b", $time, a, b, acc, q);

    $fclose(fd);
    $finish;
  end
endmodule
