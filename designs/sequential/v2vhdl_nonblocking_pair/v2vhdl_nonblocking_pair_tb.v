// Shared by both compiles in the pipeline: the untouched RTL and the same
// design after a full excursion through VHDL and back.
//
// Rising edges fall at 5, 15, 25, 35. d moves at 12, 22 and 32 - off the clock
// grid - and each row is sampled a half-cycle after the edge it reports, so no
// stimulus ever changes at the instant of an edge.
//
// d is one-hot and advances every step, so p and q hold different values on
// every row after the first. A lowering that made either assignment immediate
// would put d into both stages at once, and then q would equal p - which is
// what these rows are shaped to expose.
`timescale 1ns/1ps
module v2vhdl_nonblocking_pair_tb;
  reg clk;
  reg [3:0] d;
  wire [3:0] p, q;
  integer fd;
  reg [4095:0] tracefile;

  v2vhdl_nonblocking_pair dut (.clk(clk), .d(d), .p(p), .q(q));

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
    $fdisplay(fd, "time,d,p,q");

    d = 4'b0001;
    #12 $fdisplay(fd, "%0t,%b,%b,%b", $time, d, p, q);
    d = 4'b0010;
    #10 $fdisplay(fd, "%0t,%b,%b,%b", $time, d, p, q);
    d = 4'b0100;
    #10 $fdisplay(fd, "%0t,%b,%b,%b", $time, d, p, q);
    d = 4'b1000;
    #10 $fdisplay(fd, "%0t,%b,%b,%b", $time, d, p, q);

    $fclose(fd);
    $finish;
  end
endmodule
