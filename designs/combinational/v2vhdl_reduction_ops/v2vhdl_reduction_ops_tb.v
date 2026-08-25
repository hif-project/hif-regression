// Shared by both compiles in the pipeline: the untouched RTL and the same
// design after a full excursion through VHDL and back.
//
// The five patterns separate the three reductions from each other and from any
// constant. 0000 is the only row where any_one is 0; 1111 the only one where
// all_ones is 1; and 1100 against 1110 differ in parity while agreeing on both
// of the others, so parity cannot be confused with either.
`timescale 1ns/1ps
module v2vhdl_reduction_ops_tb;
  reg [3:0] a;
  wire any_one, all_ones, parity;
  integer fd;
  reg [4095:0] tracefile;

  v2vhdl_reduction_ops dut (.a(a), .any_one(any_one), .all_ones(all_ones), .parity(parity));

  task step;
    input [3:0] va;
    begin
      a = va;
      #1 $fdisplay(fd, "%0t,%b,%b,%b,%b", $time, a, any_one, all_ones, parity);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,a,any_one,all_ones,parity");

    step(4'b0000);
    step(4'b1111);
    step(4'b1000);
    step(4'b1100);
    step(4'b1110);

    $fclose(fd);
    $finish;
  end
endmodule
